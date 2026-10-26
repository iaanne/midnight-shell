#pragma once

#include <memory>
#include <optional>
#include <string>

namespace caelestia::services {

// GCR's "sx-aes-1" secret exchange (GcrSecretExchange).
//
// gnome-keyring-daemon and its clients never send a password over the bus in
// the clear. The prompter begins an exchange by publishing a Diffie-Hellman
// public key, the client answers with its own, and the password is then sealed
// with a key derived from the shared secret.
//
// This is deliberately Qt-free so it can be unit-tested on its own; the QML
// service converts at the boundary.
class SecretExchange {
public:
    SecretExchange();
    ~SecretExchange();

    SecretExchange(const SecretExchange&) = delete;
    SecretExchange& operator=(const SecretExchange&) = delete;

    // Starts a new exchange and returns the key-file carrying only our public
    // key. Mirrors gcr_secret_exchange_begin().
    [[nodiscard]] std::optional<std::string> begin();

    // Parses the peer's key-file, derives the transport key and, when the peer
    // sent one, decrypts the secret into `secret`. Mirrors
    // gcr_secret_exchange_receive().
    bool receive(const std::string& exchange, std::string* secret = nullptr, std::string* error = nullptr);

    // Builds a key-file carrying our public key and, when `secret` has a value,
    // the encrypted password. A disengaged optional sends a reply with no
    // secret; an empty string encrypts an empty password.
    [[nodiscard]] std::optional<std::string> send(const std::optional<std::string>& secret, std::string* error = nullptr);

    [[nodiscard]] bool derived() const;

private:
    struct Private;
    std::unique_ptr<Private> d;
};

} // namespace caelestia::services