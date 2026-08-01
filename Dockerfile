# syntax=docker/dockerfile:1.4

ARG	NODE_VERSION="24"
ARG	PI_WEB_VERSION="latest"
ARG	PI_CODING_AGENT_VERSION="latest"

FROM	node:${NODE_VERSION}-trixie-slim AS base
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<-EOF
	apt-get update
	apt-get --no-install-recommends install -y bash ca-certificates curl git python3
EOF


FROM	base AS pi
ARG	PI_CODING_AGENT_VERSION
RUN	--mount=type=cache,target=/root/.npm <<-EOF
	npm install -g --ignore-scripts \
		"@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"
EOF
RUN	test -x /usr/local/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js


FROM	base AS pi-web
ARG	PI_WEB_VERSION
RUN	--mount=type=cache,target=/root/.npm <<-EOF
	npm install -g "@agegr/pi-web@${PI_WEB_VERSION}"
EOF
RUN	test -x /usr/local/lib/node_modules/@agegr/pi-web/bin/pi-web.js


FROM	base
RUN	--mount=type=cache,target=/var/cache/apt,sharing=locked \
	--mount=type=cache,target=/var/lib/apt,sharing=locked <<-EOF
	apt-get update
	apt-get --no-install-recommends install -y jq less openssh-client ripgrep unzip vim
EOF

COPY	--from=pi --link \
	/usr/local/lib/node_modules/@earendil-works/pi-coding-agent \
	/usr/local/lib/node_modules/@earendil-works/pi-coding-agent
COPY	--from=pi-web --link \
	/usr/local/lib/node_modules/@agegr/pi-web \
	/usr/local/lib/node_modules/@agegr/pi-web
RUN	<<-EOF
	cd /usr/local/bin
	ln -sf ../lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js pi
	ln -sf ../lib/node_modules/@agegr/pi-web/bin/pi-web.js pi-web
EOF

ENV	PI_WEB_HOSTNAME="0.0.0.0" \
	PI_WEB_NO_OPEN="1" \
	PORT="30141"

WORKDIR	/home/node
EXPOSE	30141
USER	node

COPY	--chmod=755 --link ./entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT	["/usr/local/bin/entrypoint.sh"]
CMD	["/usr/local/bin/pi-web"]
