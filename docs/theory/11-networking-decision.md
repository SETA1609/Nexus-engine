# Networking Decision: Godot vs Valve GameNetworkingSockets

## Summary

Godot does **not** use Valve's GameNetworkingSockets. It uses **ENet** as its low-level networking library.

For our engine (**Nexus-engine**), we are committing **completely** to **Valve's GameNetworkingSockets (GNS)**. We will not use ENet at all (not even as a fallback). This document explains the reasoning and provides references.

---

## 1. What Does Godot Actually Use?

Godot's networking stack is built on top of **ENet**.

### Godot Networking Architecture

- **Low-level**: [ENet](https://github.com/lsalzman/enet) (by Lee Salzman)
  - Reliable and unreliable UDP
  - Simple and lightweight
- **High-level**: Godot's own `MultiplayerAPI` + `ENetMultiplayerPeer`
- Godot 4 also supports WebRTC and WebSockets for browser games.

**Official Documentation**:
- Godot Networking Overview: https://docs.godotengine.org/en/stable/tutorials/networking/index.html
- High-level Multiplayer: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html

Godot chose ENet because it is simple, mature, and sufficient for most indie multiplayer games.

---

## 2. What is Valve GameNetworkingSockets?

**GameNetworkingSockets** (commonly called **GNS**) is Valve's open-source networking library. It powers many of Valve's own games (Dota 2, Counter-Strike 2, etc.) and is used by numerous third-party titles.

### Key Features

- Reliable + unreliable messaging over UDP
- Automatic fragmentation and reassembly
- Strong NAT traversal and relay support (via Steam)
- Built-in encryption
- Connection-oriented API
- Excellent performance and scalability

**License**: MIT (very permissive)

**GitHub Repository**:
- https://github.com/ValveSoftware/GameNetworkingSockets

---

## 3. Comparison: ENet vs GameNetworkingSockets

| Feature                        | ENet (Godot)                     | Valve GameNetworkingSockets          | Winner for Modern Engine |
|--------------------------------|----------------------------------|--------------------------------------|--------------------------|
| **Maturity**                   | Very mature                      | Very mature (used in AAA)            | Similar                  |
| **Features**                   | Basic reliable/unreliable UDP    | Rich feature set (fragmentation, relays, encryption) | **GNS** |
| **NAT Traversal**              | Basic                            | Excellent                            | **GNS** |
| **Steam Integration**          | None                             | Native                               | **GNS** |
| **Complexity**                 | Low                              | Medium                               | ENet                     |
| **Size & Dependencies**        | Very small                       | Larger                               | ENet                     |
| **Zig Integration**            | Easy (C library)                 | Good (C API available)               | Similar                  |
| **Modern Architecture**        | Older design                     | Modern and actively maintained       | **GNS** |
| **Scalability**                | Good for small-medium games      | Excellent (used in large-scale games)| **GNS** |

---

## 4. Recommendation for Nexus-engine

**We recommend using Valve's GameNetworkingSockets** as the primary low-level networking library for the following reasons:

### Why GNS Makes Sense for Us

- We want a **modern** networking foundation from the beginning.
- Strong NAT traversal and relay support will be valuable for players behind restrictive networks.
- Future Steam integration becomes much easier.
- It is more feature-complete than ENet, reducing the amount of custom code we need to write on top.
- Battle-tested at very large scale (Valve games).

### Proposed Architecture

```ascii
Nexus-engine Networking Layer
─────────────────────────────
High-Level Networking (Nexus-engine)
    ├── RPC System
    ├── State Replication
    └── NetworkManager / NetworkSystem
           │
           ▼
Low-Level Transport
    └── GameNetworkingSockets (GNS)
           │
           ▼
zGameLib (optional thin wrapper if needed)
```

---

## 5. References & Documentation

### Valve GameNetworkingSockets

- **Official GitHub**: https://github.com/ValveSoftware/GameNetworkingSockets
- **Documentation** (inside the repo):
  - `README.md` and `docs/` folder in the repository

### Godot Networking

- **Godot Networking Documentation**: https://docs.godotengine.org/en/stable/tutorials/networking/index.html
- **High Level Multiplayer**: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Godot uses **ENet** under the hood (confirmed in source code and documentation).

### Additional Resources

- ENet Official Site: http://enet.bespin.org/
- Steamworks Documentation (for relay and authentication features when integrating with Steam)

---

## 6. Final Decision Summary

| Question                                      | Answer |
|-----------------------------------------------|--------|
| Does Godot use GameNetworkingSockets?         | No     |
| Should we use GameNetworkingSockets in Nexus-engine? | **Yes** (committing fully to GNS) |
| Should we keep ENet as an option?             | **No** – Moving completely to GameNetworkingSockets |
| When should we implement this?                | Before building high-level replication / multiplayer systems |

This decision aligns with our goal of building a **modern, modular, and explicit** engine while learning from both Godot's simplicity and Valve's production-grade networking stack.

---

*Document created on 2026-07-15 based on official documentation and public information about Godot and Valve GameNetworkingSockets.*
