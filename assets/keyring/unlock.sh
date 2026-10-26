#!/usr/bin/env bash
# Unlocks the GNOME login keyring with the password entered on the lock screen.
#
# The password is passed in UNLOCK_PASSWORD so it never appears on the command
# line. The script is deliberately best-effort: when gnome-keyring is not
# installed or in use, the login collection is already unlocked, or the
# password does not match the keyring, it exits without changing anything, so
# applications keep prompting for the keyring password as they did before.

set -u

password="${UNLOCK_PASSWORD:-}"
unset UNLOCK_PASSWORD

[[ -n "$password" ]] || exit 0

command -v gnome-keyring-daemon >/dev/null 2>&1 || exit 0

# True while the login collection is locked (or cannot be queried).
keyring_locked() {
    local state
    state="$(busctl --user get-property org.freedesktop.secrets \
        /org/freedesktop/secrets/collection/login \
        org.freedesktop.Secret.Collection Locked 2>/dev/null || true)"
    [[ "$state" != "b false" ]]
}

# Nothing to do when the login collection is already unlocked.
command -v busctl >/dev/null 2>&1 && ! keyring_locked && exit 0

# A daemon that is already running will not accept a second login attempt, so
# replace it. killall truncates the long process name for us; pkill -f is the
# fallback.
if command -v killall >/dev/null 2>&1; then
    killall -q -u "$(id -un)" gnome-keyring-daemon 2>/dev/null || true
elif command -v pkill >/dev/null 2>&1; then
    pkill -u "$(id -u)" -f 'gnome-keyring-daemon' 2>/dev/null || true
fi

# --login implies --unlock and reads the password from stdin. It leaves the
# daemon half-initialised, so --start is run afterwards to complete it.
login_env="$(printf '%s' "$password" | gnome-keyring-daemon --daemonize --login 2>/dev/null || true)"
while IFS= read -r line; do
    [[ "$line" == [A-Za-z_]*=* ]] && export "$line"
done <<< "$login_env"

gnome-keyring-daemon --start --components=secrets >/dev/null 2>&1 || true

# Report success only when the collection actually ended up unlocked.
if command -v busctl >/dev/null 2>&1 && ! keyring_locked; then
    exit 0
fi

exit 1
