# syntax=docker/dockerfile:1.4

ARG	NODE_VERSION="24"
ARG	PI_WEB_VERSION="latest"
ARG	PI_CODING_AGENT_VERSION="latest"

ARG	INSTALL_DIR="/app"
ARG	DEBIAN_PACKAGES="sudo bash curl git openssh-client python3-pip jq less ripgrep fd-find tree unzip vim file procps psmisc"
ARG	SUDO_PASSWORD=

FROM	node:${NODE_VERSION}-trixie-slim AS base
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<-EOF
	apt-get update
	apt-get install -y --no-install-recommends ca-certificates
EOF


FROM	base AS app
ARG	PI_CODING_AGENT_VERSION PI_WEB_VERSION
ARG	INSTALL_DIR
RUN	--mount=type=cache,target=/root/.npm <<-EOF
	npm install -g --ignore-scripts --prefix="${INSTALL_DIR}" \
		"@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}" \
		"@agegr/pi-web@${PI_WEB_VERSION}"
EOF
RUN	test -x "${INSTALL_DIR}/bin/pi-web"


FROM	base
ARG	DEBIAN_PACKAGES
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<-EOF
	apt-get update
	apt-get --no-install-recommends install -y ${DEBIAN_PACKAGES}
EOF

ARG	SUDO_PASSWORD
RUN	<<-EOF
	if command -v sudo; then
		mkdir -p /etc/sudoers.d
		if [ -n "${SUDO_PASSWORD}" ]; then
			echo "node	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/node
			echo "node:${SUDO_PASSWORD}" | chpasswd
		else
			echo "node	ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/node
		fi
	fi
EOF

ARG	INSTALL_DIR
COPY	--from=app --link ${INSTALL_DIR} /app
RUN	<<-EOF
	cd /usr/local/bin
	ln -sf /app/bin/pi pi
EOF

ENV	PI_WEB_HOSTNAME="0.0.0.0" \
	PI_WEB_NO_OPEN="1" \
	PORT="30141"

WORKDIR	/workspaces
EXPOSE	30141
USER	node

COPY	--chmod=755 --link ./entrypoint.sh /app/entrypoint.sh
ENTRYPOINT	["/app/entrypoint.sh"]
CMD	["/app/bin/pi-web"]
