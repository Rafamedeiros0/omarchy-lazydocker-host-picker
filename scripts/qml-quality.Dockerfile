FROM archlinux:base-20260913.0.592969@sha256:204e91950fd364961088a01773eee9012243b7e965fed42b1d82d12416190782

RUN echo 'Server = https://archive.archlinux.org/repos/2026/09/13/$repo/os/$arch' > /etc/pacman.d/mirrorlist \
    && pacman -Syyuu --noconfirm git diffutils \
    && pacman -S --needed --noconfirm qt6-declarative quickshell \
    && pacman -Scc --noconfirm

WORKDIR /workspace
