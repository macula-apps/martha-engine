#!/usr/bin/env bash
# serve_the_trial_model.sh <dir> <evidence>: installs the pinned Ollama under <dir>, serves it on its default local
# port, and pulls the pinned model, refusing a download or a model whose digest is not the pinned one. The server's
# own log is written into <evidence>, which the checks upload as the run's trial evidence (macula-io/martha#822): a
# line cut at its cap and a request the model never answered read alike without it.
#
# The #541 trial lines run the engine against a local model so no line needs a provider key and nothing leaves the
# runner for a model (macula-io/martha#547 S2). Linux x86_64 only: the hosted runner the checks use.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=pins.env
source "${here}/pins.env"
dir="${1:?usage: serve_the_trial_model.sh <dir> <evidence>}"
evidence="${2:?usage: serve_the_trial_model.sh <dir> <evidence>}"
mkdir -p "${dir}/ollama" "${dir}/models" "${evidence}"

curl --fail --silent --show-error --location --output "${dir}/${OLLAMA_ASSET}" \
  "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/${OLLAMA_ASSET}"
echo "${OLLAMA_SHA256}  ${dir}/${OLLAMA_ASSET}" | sha256sum --check --quiet
tar --zstd -xf "${dir}/${OLLAMA_ASSET}" -C "${dir}/ollama"

OLLAMA_MODELS="${dir}/models" nohup "${dir}/ollama/bin/ollama" serve > "${evidence}/${TRIAL_SERVER_LOG}" 2>&1 &
for _ in $(seq 60); do
  curl --fail --silent http://127.0.0.1:11434/api/version > /dev/null && break
  sleep 1
done
"${dir}/ollama/bin/ollama" pull "${TRIAL_MODEL}"

digest="$(curl --fail --silent http://127.0.0.1:11434/api/tags | jq -r --arg name "${TRIAL_MODEL}" '.models[] | select(.name == $name) | .digest')"
[[ "${digest}" == "${TRIAL_MODEL_DIGEST}" ]] \
  || { echo "serve_the_trial_model: ${TRIAL_MODEL} has digest '${digest}', not the pinned ${TRIAL_MODEL_DIGEST}" >&2; exit 1; }
echo "serving ${TRIAL_MODEL} (${digest}) on Ollama ${OLLAMA_VERSION}"
