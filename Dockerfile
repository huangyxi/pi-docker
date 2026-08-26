# syntax=docker/dockerfile:1.4

ARG	NODE_VERSION="26"
ARG	PI_WEB_VERSION="latest"
ARG	PI_CODING_AGENT_VERSION="latest"

ARG	INSTALL_DIR="/app"
ARG	DEBIAN_PACKAGES="sudo bash curl ca-certificates git openssh-client python3-pip jq less ripgrep fd-find tree unzip vim file procps psmisc"
ARG	SUDO_PASSWORD=

FROM	node:${NODE_VERSION}-trixie-slim AS base


FROM	base AS app
ARG	INSTALL_DIR PI_WEB_VERSION PI_CODING_AGENT_VERSION
WORKDIR	${INSTALL_DIR}
RUN	--mount=type=cache,target=/root/.npm <<-EOF
	echo "Installing @agegr/pi-web@${PI_WEB_VERSION} and @earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}..."
	npm install --ignore-scripts --prefix ${INSTALL_DIR} \
		"@agegr/pi-web@${PI_WEB_VERSION}" \
		"@earendil-works/pi-coding-agent"
	mkdir bin
	ln -sf ../node_modules/.bin/pi bin/pi
	ln -sf ../node_modules/.bin/pi-web bin/pi-web
EOF
RUN	test -x "${INSTALL_DIR}/bin/pi-web"


FROM	base AS pnpm
RUN	--mount=type=cache,target=/root/.npm <<-EOF
	npm install --global pnpm
EOF
RUN	test -x "/usr/local/bin/pnpm"


FROM	base
ARG	DEBIAN_PACKAGES
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<-EOF
	apt-get update
	apt-get install --no-install-recommends --yes ${DEBIAN_PACKAGES}
EOF

RUN	<<-EOF
	command -v curl && curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL=/usr/local/bin sh
EOF

ARG	SUDO_PASSWORD
RUN	<<-EOF
	if ! command -v sudo; then
		echo "sudo is not installed, skipping sudo configuration"
		exit 0
	fi
	mkdir -p /etc/sudoers.d
	if [ -n "${SUDO_PASSWORD}" ]; then
		echo "node	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/node
		echo "node:${SUDO_PASSWORD}" | chpasswd
	else
		echo "node	ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/node
	fi
EOF

ARG	INSTALL_DIR
COPY	--from=app --link ${INSTALL_DIR} /app
COPY	--from=pnpm --link /usr/local/lib/node_modules/pnpm /usr/local/lib/node_modules/pnpm
RUN	<<-EOF
	cd /usr/local/bin
	ln -sf /app/bin/pi pi
	ln -sf ../lib/node_modules/pnpm/bin/pnpx.mjs pn
	ln -sf ../lib/node_modules/pnpm/bin/pnpm.mjs pnpm
	ln -sf ../lib/node_modules/pnpm/bin/pnpx.mjs pnpx
	ln -sf ../lib/node_modules/pnpm/bin/pnpx.mjs pnx
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
