pragma Singleton

import QtQuick
import qs.services

/**
 * NetworkConnection
 *
 * Centralized utility for network connection logic. Provides a single source of truth
 * for connecting to wireless networks, eliminating code duplication across
 * controlcenter components and bar popouts.
 *
 * Usage:
 * ```qml
 * import qs.utils
 *
 * // With Session object (controlcenter)
 * NetworkConnection.handleConnect(network, session);
 *
 * // Without Session object (bar popouts) - provide password dialog callback
 * NetworkConnection.handleConnect(network, null, (network) => {
 *     // Show password dialog
 *     root.passwordNetwork = network;
 *     root.showPasswordDialog = true;
 * });
 * ```
 */
QtObject {
    id: root

    /**
     * Handle network connection with automatic disconnection if needed.
     * If there's an active network different from the target, disconnects first,
     * then connects to the target network.
     *
     * @param network The network object to connect to (must have ssid property)
     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
     */
    function handleConnect(network, session, onPasswordNeeded): void {
        if (!network) {
            return;
        }

        if (Nmcli.active && Nmcli.active.ssid !== network.ssid) {
            Nmcli.disconnectFromNetwork();
            Qt.callLater(() => {
                root.connectToNetwork(network, session, onPasswordNeeded);
            });
        } else {
            root.connectToNetwork(network, session, onPasswordNeeded);
        }
    }

    /**
     * Connect to a wireless network.
     * Handles both secured and open networks, checks for saved profiles,
     * and shows password dialog if needed.
     *
     * @param network The network object to connect to (must have ssid, isSecure, bssid properties)
     * @param session Optional Session object (for controlcenter - must have network property with showPasswordDialog and pendingNetwork)
     * @param onPasswordNeeded Optional callback function(network) called when password is needed (for bar popouts)
     */
    function connectToNetwork(network, session, onPasswordNeeded): void {
        if (!network) {
            return;
        }

        if (network.isSecure) {
            const hasSavedProfile = Nmcli.hasSavedProfile(network.ssid);

            if (hasSavedProfile) {
                Nmcli.connectToNetwork(network.ssid, "", network.bssid, null);
            } else if (root.needsSecurityConfig(network)) {
                // Enterprise (802.1X) and WEP can't be attempted with an empty
                // secret: go straight to the credentials dialog so the user can
                // fill in the identity / key that the network needs.
                if (session && session.network) {
                    session.network.showPasswordDialog = true;
                    session.network.pendingNetwork = network;
                } else if (onPasswordNeeded) {
                    onPasswordNeeded(network);
                }
            } else {
                // Use password check with callback
                Nmcli.connectToNetworkWithPasswordCheck(network.ssid, network.isSecure, result => {
                    if (result.needsPassword) {
                        // Clear pending connection if exists
                        if (Nmcli.pendingConnection) {
                            Nmcli.connectionCheckTimer.stop();
                            Nmcli.immediateCheckTimer.stop();
                            Nmcli.immediateCheckTimer.checkCount = 0;
                            Nmcli.pendingConnection = null;
                        }

                        // Handle password dialog - use session if available, otherwise use callback
                        if (session && session.network) {
                            session.network.showPasswordDialog = true;
                            session.network.pendingNetwork = network;
                        } else if (onPasswordNeeded) {
                            onPasswordNeeded(network);
                        }
                    }
                }, network.bssid);
            }
        } else {
            Nmcli.connectToNetwork(network.ssid, "", network.bssid, null);
        }
    }

    /**
     * Connect to a wireless network with a provided password.
     * Used by password dialogs when the user has already entered a password.
     *
     * @param network The network object to connect to (must have ssid, bssid properties)
     * @param password The password to use for connection
     * @param onResult Optional callback function(result) called with connection result
     */
    function connectWithPassword(network, password, onResult): void {
        if (!network) {
            return;
        }

        // SAE (WPA3) and WEP need the matching key-mgmt, which the generic
        // password path hard-codes to WPA-PSK.
        const kind = Nmcli.securityKind(network.security);
        if (kind === Nmcli.securityKindSae || kind === Nmcli.securityKindWep) {
            Nmcli.connectWithConfig(network.ssid, {
                security: kind,
                password: password || ""
            }, network.bssid || "", onResult || null);
            return;
        }

        Nmcli.connectToNetwork(network.ssid, password || "", network.bssid || "", onResult || null);
    }

    /**
     * Whether this network needs a full security configuration (enterprise /
     * 802.1X or WEP) instead of a plain WPA password.
     *
     * @param network The network object to check (must have a security property)
     */
    function needsSecurityConfig(network): bool {
        if (!network) {
            return false;
        }
        const kind = Nmcli.securityKind(network.security);
        return kind === Nmcli.securityKindEnterprise || kind === Nmcli.securityKindWep;
    }

    /**
     * Connect to a wireless network using a full security configuration.
     * Used by the credentials dialog for enterprise / WEP networks.
     *
     * @param network The network object to connect to (must have ssid, bssid)
     * @param config Security configuration, e.g. { security, password, identity, eap, phase2, anonIdentity, caCert }
     * @param onResult Optional callback function(result) called with connection result
     */
    function connectWithConfig(network, config, onResult): void {
        if (!network) {
            return;
        }

        Nmcli.connectWithConfig(network.ssid, config || {}, network.bssid || "", onResult || null);
    }
}
