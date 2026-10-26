#include "secretexchange.hpp"

#include <openssl/bn.h>
#include <openssl/crypto.h>
#include <openssl/evp.h>
#include <openssl/kdf.h>
#include <openssl/rand.h>

#include <array>
#include <cstdint>
#include <unordered_map>
#include <utility>
#include <vector>

namespace caelestia::services {

namespace {

// The 1536-bit MODP group (RFC 3526 group 5) prime used by gcr's
// dh_group_1536_prime. Shared secrets are padded to its byte length before key
// derivation, so a transcription slip here silently breaks interop.
constexpr const char* kPrimeHex =
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"
    "29024E088A67CC74020BBEA63B139B22514A08798E3404DD"
    "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"
    "E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
    "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D"
    "C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F"
    "83655D23DCA3AD961C62F356208552BB9ED529077096966D"
    "670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF";

constexpr std::size_t kPrimeLength = 192;
constexpr int kAesKeyLength = 16;
constexpr int kAesBlockLength = 16;

void setError(std::string* error, const char* message) {
    if (error != nullptr)
        *error = message;
}

void setError(std::string* error, const std::string& message) {
    if (error != nullptr)
        *error = message;
}

std::string trim(const std::string& value) {
    const auto begin = value.find_first_not_of(" \t\r\n");
    if (begin == std::string::npos)
        return {};
    const auto end = value.find_last_not_of(" \t\r\n");
    return value.substr(begin, end - begin + 1);
}

std::string base64Encode(const std::string& data) {
    // EVP_EncodeBlock writes a trailing NUL, so reserve one byte for it.
    std::string out(4 * ((data.size() + 2) / 3) + 1, '\0');
    const int written = EVP_EncodeBlock(
        reinterpret_cast<unsigned char*>(out.data()), reinterpret_cast<const unsigned char*>(data.data()), static_cast<int>(data.size()));
    if (written < 0)
        return {};
    out.resize(static_cast<std::size_t>(written));
    return out;
}

bool base64Decode(const std::string& data, std::string* out, std::string* error) {
    std::string clean;
    clean.reserve(data.size());
    for (const char c : data) {
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n')
            continue;
        clean += c;
    }

    if (clean.empty() || clean.size() % 4 != 0) {
        setError(error, "secret exchange: invalid base64 length");
        return false;
    }

    out->assign(3 * (clean.size() / 4), '\0');
    const int written =
        EVP_DecodeBlock(reinterpret_cast<unsigned char*>(out->data()), reinterpret_cast<const unsigned char*>(clean.data()), static_cast<int>(clean.size()));
    if (written < 0) {
        setError(error, "secret exchange: invalid base64 data");
        return false;
    }

    std::size_t padding = 0;
    if (clean.ends_with("=="))
        padding = 2;
    else if (clean.ends_with("="))
        padding = 1;
    out->resize(static_cast<std::size_t>(written) - padding);
    return true;
}

struct KeyFile {
    std::unordered_map<std::string, std::string> values;
};

KeyFile parseKeyFile(const std::string& exchange) {
    KeyFile out;
    std::size_t start = 0;
    while (start <= exchange.size()) {
        const auto end = exchange.find('\n', start);
        const auto line = trim(exchange.substr(start, end == std::string::npos ? std::string::npos : end - start));
        start = end == std::string::npos ? exchange.size() + 1 : end + 1;

        if (line.empty() || line.starts_with('[') || line.starts_with('#') || line.starts_with(';'))
            continue;

        const auto equals = line.find('=');
        if (equals == std::string::npos || equals == 0)
            continue;

        out.values[trim(line.substr(0, equals))] = trim(line.substr(equals + 1));
    }
    return out;
}

std::string encodeKeyFile(const std::vector<std::pair<std::string, std::string>>& entries) {
    std::string out = "[sx-aes-1]\n";
    for (const auto& [key, value] : entries) {
        out += key;
        out += '=';
        out += value;
        out += '\n';
    }
    return out;
}

bool deriveTransportKey(const std::string& ikm, std::string* key, std::string* error) {
    // egg_hkdf_perform treats a null salt as HashLen zero bytes and a null info
    // as empty; match that with an explicit 32-byte zero salt and no info.
    const std::array<unsigned char, 32> salt{};

    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_HKDF, nullptr);
    if (ctx == nullptr) {
        setError(error, "secret exchange: failed to allocate HKDF context");
        return false;
    }

    bool ok = EVP_PKEY_derive_init(ctx) > 0 && EVP_PKEY_CTX_set_hkdf_md(ctx, EVP_sha256()) > 0;
    if (ok)
        ok = EVP_PKEY_CTX_set1_hkdf_salt(ctx, salt.data(), static_cast<int>(salt.size())) > 0;
    if (ok)
        ok = EVP_PKEY_CTX_set1_hkdf_key(ctx, reinterpret_cast<const unsigned char*>(ikm.data()), static_cast<int>(ikm.size())) > 0;

    std::size_t length = kAesKeyLength;
    key->assign(kAesKeyLength, '\0');
    if (ok)
        ok = EVP_PKEY_derive(ctx, reinterpret_cast<unsigned char*>(key->data()), &length) > 0 && length == kAesKeyLength;
    EVP_PKEY_CTX_free(ctx);

    if (!ok) {
        OPENSSL_cleanse(key->data(), key->size());
        key->clear();
        setError(error, "secret exchange: HKDF derivation failed");
        return false;
    }
    return true;
}

bool encrypt(const std::string& key, const std::string& plain, std::string* ciphertext, std::string* iv, std::string* error) {
    iv->assign(kAesBlockLength, '\0');
    if (RAND_bytes(reinterpret_cast<unsigned char*>(iv->data()), kAesBlockLength) != 1) {
        setError(error, "secret exchange: failed to generate IV");
        return false;
    }

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (ctx == nullptr) {
        setError(error, "secret exchange: failed to allocate cipher context");
        return false;
    }

    const std::size_t maxLength = plain.size() + kAesBlockLength;
    ciphertext->assign(maxLength, '\0');
    int written = 0;
    int finalWritten = 0;
    bool ok = EVP_EncryptInit_ex(ctx, EVP_aes_128_cbc(), nullptr, reinterpret_cast<const unsigned char*>(key.data()),
                  reinterpret_cast<const unsigned char*>(iv->data())) > 0;
    if (ok)
        ok = EVP_EncryptUpdate(ctx, reinterpret_cast<unsigned char*>(ciphertext->data()), &written,
                 reinterpret_cast<const unsigned char*>(plain.data()), static_cast<int>(plain.size())) > 0;
    if (ok)
        ok = EVP_EncryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(ciphertext->data()) + written, &finalWritten) > 0;
    EVP_CIPHER_CTX_free(ctx);

    if (!ok) {
        setError(error, "secret exchange: encryption failed");
        return false;
    }
    ciphertext->resize(static_cast<std::size_t>(written + finalWritten));
    return true;
}

bool decrypt(const std::string& key, const std::string& ciphertext, const std::string& iv, std::string* plain, std::string* error) {
    if (iv.size() != kAesBlockLength) {
        setError(error, "secret exchange: bad iv length");
        return false;
    }
    if (ciphertext.empty() || ciphertext.size() % kAesBlockLength != 0) {
        setError(error, "secret exchange: bad ciphertext length");
        return false;
    }

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (ctx == nullptr) {
        setError(error, "secret exchange: failed to allocate cipher context");
        return false;
    }

    plain->assign(ciphertext.size(), '\0');
    int written = 0;
    int finalWritten = 0;
    bool ok = EVP_DecryptInit_ex(ctx, EVP_aes_128_cbc(), nullptr, reinterpret_cast<const unsigned char*>(key.data()),
                  reinterpret_cast<const unsigned char*>(iv.data())) > 0;
    if (ok)
        ok = EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char*>(plain->data()), &written,
                 reinterpret_cast<const unsigned char*>(ciphertext.data()), static_cast<int>(ciphertext.size())) > 0;
    if (ok)
        ok = EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(plain->data()) + written, &finalWritten) > 0;
    EVP_CIPHER_CTX_free(ctx);

    if (!ok) {
        setError(error, "secret exchange: decryption failed");
        return false;
    }
    plain->resize(static_cast<std::size_t>(written + finalWritten));
    return true;
}

} // namespace

struct SecretExchange::Private {
    BIGNUM* prime = nullptr;
    BIGNUM* generator = nullptr;
    BIGNUM* privateKey = nullptr;
    BIGNUM* publicKey = nullptr;
    std::string transportKey;
    bool derived = false;

    Private() {
        BN_hex2bn(&prime, kPrimeHex);
        generator = BN_new();
        if (generator != nullptr)
            BN_set_word(generator, 2);
    }

    ~Private() {
        BN_clear_free(privateKey);
        BN_free(publicKey);
        BN_free(prime);
        BN_free(generator);
        OPENSSL_cleanse(transportKey.data(), transportKey.size());
    }

    void reset() {
        BN_clear_free(privateKey);
        BN_free(publicKey);
        privateKey = nullptr;
        publicKey = nullptr;
        OPENSSL_cleanse(transportKey.data(), transportKey.size());
        transportKey.clear();
        derived = false;
    }

    bool generate(std::string* error) {
        if (privateKey != nullptr)
            return true;
        if (prime == nullptr || generator == nullptr) {
            setError(error, "secret exchange: DH parameters unavailable");
            return false;
        }

        BN_CTX* ctx = BN_CTX_new();
        if (ctx == nullptr) {
            setError(error, "secret exchange: failed to allocate BN context");
            return false;
        }

        BIGNUM* range = BN_dup(prime);
        BIGNUM* exponent = BN_new();
        BIGNUM* publicValue = BN_new();
        bool ok = range != nullptr && exponent != nullptr && publicValue != nullptr;
        if (ok)
            ok = BN_sub_word(range, 2) == 1;
        if (ok)
            ok = BN_priv_rand_range(exponent, range) == 1;
        if (ok)
            ok = BN_add_word(exponent, 1) == 1;
        if (ok)
            ok = BN_mod_exp(publicValue, generator, exponent, prime, ctx) == 1;

        BN_CTX_free(ctx);
        BN_free(range);

        if (!ok) {
            BN_clear_free(exponent);
            BN_free(publicValue);
            setError(error, "secret exchange: failed to generate DH keypair");
            return false;
        }

        privateKey = exponent;
        publicKey = publicValue;
        return true;
    }

    std::string encodePublic() const {
        std::string bytes(static_cast<std::size_t>(BN_num_bytes(publicKey)), '\0');
        BN_bn2bin(publicKey, reinterpret_cast<unsigned char*>(bytes.data()));
        return base64Encode(bytes);
    }
};

SecretExchange::SecretExchange()
    : d(std::make_unique<Private>()) {}

SecretExchange::~SecretExchange() = default;

bool SecretExchange::derived() const {
    return d->derived;
}

std::optional<std::string> SecretExchange::begin() {
    d->reset();
    std::string error;
    if (!d->generate(&error))
        return std::nullopt;
    return encodeKeyFile({ { "public", d->encodePublic() } });
}

bool SecretExchange::receive(const std::string& exchange, std::string* secret, std::string* error) {
    if (secret != nullptr)
        secret->clear();

    const auto fields = parseKeyFile(exchange);

    if (!d->generate(error))
        return false;

    if (!d->derived) {
        const auto publicIt = fields.values.find("public");
        if (publicIt == fields.values.end() || publicIt->second.empty()) {
            setError(error, "secret exchange: missing public key");
            return false;
        }

        std::string peerBytes;
        if (!base64Decode(publicIt->second, &peerBytes, error))
            return false;

        BIGNUM* peer = BN_bin2bn(reinterpret_cast<const unsigned char*>(peerBytes.data()), static_cast<int>(peerBytes.size()), nullptr);
        if (peer == nullptr) {
            setError(error, "secret exchange: invalid public key");
            return false;
        }

        const bool valid = !BN_is_zero(peer) && !BN_is_one(peer) && BN_cmp(peer, d->prime) < 0;
        if (!valid) {
            BN_free(peer);
            setError(error, "secret exchange: invalid public key");
            return false;
        }

        BN_CTX* ctx = BN_CTX_new();
        BIGNUM* shared = BN_new();
        bool ok = ctx != nullptr && shared != nullptr;
        if (ok)
            ok = BN_mod_exp(shared, peer, d->privateKey, d->prime, ctx) == 1;

        std::string ikm(kPrimeLength, '\0');
        if (ok)
            ok = static_cast<std::size_t>(BN_bn2binpad(shared, reinterpret_cast<unsigned char*>(ikm.data()), static_cast<int>(kPrimeLength))) == kPrimeLength;

        BN_CTX_free(ctx);
        BN_clear_free(shared);
        BN_free(peer);

        if (!ok) {
            OPENSSL_cleanse(ikm.data(), ikm.size());
            setError(error, "secret exchange: DH key agreement failed");
            return false;
        }

        const bool derivedOk = deriveTransportKey(ikm, &d->transportKey, error);
        OPENSSL_cleanse(ikm.data(), ikm.size());
        if (!derivedOk)
            return false;
        d->derived = true;
    }

    const auto secretIt = fields.values.find("secret");
    if (secretIt == fields.values.end() || secret == nullptr)
        return true;

    const auto ivIt = fields.values.find("iv");
    if (ivIt == fields.values.end() || ivIt->second.empty()) {
        setError(error, "secret exchange: missing iv");
        return false;
    }

    std::string iv;
    std::string ciphertext;
    if (!base64Decode(ivIt->second, &iv, error) || !base64Decode(secretIt->second, &ciphertext, error))
        return false;

    const bool ok = decrypt(d->transportKey, ciphertext, iv, secret, error);
    OPENSSL_cleanse(iv.data(), iv.size());
    OPENSSL_cleanse(ciphertext.data(), ciphertext.size());
    return ok;
}

std::optional<std::string> SecretExchange::send(const std::optional<std::string>& secret, std::string* error) {
    if (!d->derived) {
        setError(error, "secret exchange: key not yet derived");
        return std::nullopt;
    }

    std::vector<std::pair<std::string, std::string>> entries{ { "public", d->encodePublic() } };
    if (secret.has_value()) {
        std::string ciphertext;
        std::string iv;
        if (!encrypt(d->transportKey, *secret, &ciphertext, &iv, error))
            return std::nullopt;
        entries.emplace_back("secret", base64Encode(ciphertext));
        entries.emplace_back("iv", base64Encode(iv));
        OPENSSL_cleanse(ciphertext.data(), ciphertext.size());
        OPENSSL_cleanse(iv.data(), iv.size());
    }

    return encodeKeyFile(entries);
}

} // namespace caelestia::services