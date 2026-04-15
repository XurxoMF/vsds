#!/usr/bin/env bash
# CLI_InstallScript.sh - Interactive version selector
# Usage: ./CLI_InstallScript.sh
set -euo pipefail

REPO="XurxoMF/vsds"
BRANCH="main"

die() {
    echo "Error: $*" >&2
    exit 1
}

check_dependencies() {
    for cmd in curl jq docker; do
        if ! command -v "$cmd" &>/dev/null; then
            die "'$cmd' is required but not installed."
        fi
    done
}

fetch_repo_tree() {
    local api_url="https://api.github.com/repos/$REPO/git/trees/$BRANCH?recursive=1"
    local response
    response=$(curl -s "$api_url")

    if echo "$response" | grep -q "API rate limit exceeded"; then
        die "GitHub API rate limit exceeded (60/hour). Try later."
    fi
    if echo "$response" | grep -q "Not Found"; then
        die "Repository '$REPO' or branch '$BRANCH' not found."
    fi
    echo "$response"
}

get_major_versions() {
    local tree_json="$1"
    echo "$tree_json" | jq -r '.tree[] | select(.type=="tree") | .path' |
        grep -v '/\.' | awk -F/ '{print $1}' | grep -v '^\.' | sort -uV
}

get_minor_versions() {
    local tree_json="$1"
    local major="$2"
    echo "$tree_json" | jq -r '.tree[] | select(.type=="tree") | .path' |
        grep "^$major/" | grep -v '/\.' | awk -F/ '{print $2}' | sort -uV
}

path_exists() {
    local tree_json="$1"
    local target_path="$2"
    echo "$tree_json" | jq -r --arg path "$target_path" '.tree[] | select(.path==$path) | .path' | grep -q .
}

download_file() {
    local remote_path="$1"
    local local_path="$2"
    local raw_url="https://raw.githubusercontent.com/$REPO/$BRANCH/$remote_path"
    echo "Downloading $remote_path ..."
    curl -s -f -o "$local_path" "$raw_url" || die "Failed to download $remote_path"
}

# Interactive selection.
# Parameters:
#   $1 - prompt
#   $2 - array name (reference)
#   $3 - allow_back ("true"/"false")
# Returns:
#   0 - success ($selected_version set)
#   1 - back
#   2 - quit
choose_version() {
    local prompt="$1"
    local -n versions="$2"
    local allow_back="${3:-false}"

    echo "$prompt"
    printf '  %s\n' "${versions[@]}"

    echo "  (press 'q' to quit)"

    while true; do
        read -r -p "Your choice: " choice
        case "$choice" in
            q|Q) return 1 ;;

            *)
                for v in "${versions[@]}"; do
                    if [[ "$choice" == "$v" ]]; then
                        selected_version="$choice"
                        return 0
                    fi
                done
                echo "Invalid. Type a version or 'q' to quit."
                ;;
        esac
    done
}

# --- Main ---
[[ -z "$REPO" ]] && die "Usage: $0 owner/repo [branch]"
check_dependencies

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Fetching repository structure from $REPO ($BRANCH)..."
TREE_JSON=$(fetch_repo_tree)

# --- Major selection (no back) ---
mapfile -t major_versions < <(get_major_versions "$TREE_JSON")
[[ ${#major_versions[@]} -eq 0 ]] && die "No version directories found in repository root."

choose_version "Available major versions:" major_versions "false"
major_ret=$?
case $major_ret in
    1) echo "Exiting."; exit 0 ;;
    0) MAJOR="$selected_version" ;;
    *) exit 1 ;;
esac

# --- Minor selection (with back) ---
while true; do
    mapfile -t minor_versions < <(get_minor_versions "$TREE_JSON" "$MAJOR")
    [[ ${#minor_versions[@]} -eq 0 ]] && die "No minor versions found under '$MAJOR'."

    choose_version "Available minor versions for version '$MAJOR':" minor_versions "true"
    minor_ret=$?

    case $minor_ret in
        1) echo "Exiting."; exit 0 ;;
        0) MINOR="$selected_version"; break ;;
    esac
done

# --- Download Dockerfile and any additional files needed for the build context ---
DOCKERFILE_PATH="$MAJOR/$MINOR/Dockerfile"
path_exists "$TREE_JSON" "$DOCKERFILE_PATH" || die "Dockerfile not found at '$DOCKERFILE_PATH'."

download_file "$DOCKERFILE_PATH" "$WORK_DIR/Dockerfile"

# If entrypoint.sh exists, download it as well (it's likely referenced in the Dockerfile)
ENTRYPOINT_PATH="$MAJOR/$MINOR/entrypoint.sh"
if path_exists "$TREE_JSON" "$ENTRYPOINT_PATH"; then
    download_file "$ENTRYPOINT_PATH" "$WORK_DIR/entrypoint.sh"
    chmod +x "$WORK_DIR/entrypoint.sh"
fi

# You can download other required files (e.g., requirements.txt, scripts) similarly if needed.
# For simplicity, we assume the Dockerfile only needs what's in the same directory.

# --- Build Docker image ---
IMAGE_TAG="$(echo "${REPO##*/}" | tr '[:upper:]' '[:lower:]'):${MAJOR}-${MINOR}"
IMAGE_TAG="${IMAGE_TAG//\//-}"   # remove any slashes from tag
echo "Building Docker image: $IMAGE_TAG from $WORK_DIR"
docker build -t "$IMAGE_TAG" "$WORK_DIR"

# --- Run container in detached mode with a persistent name ---
CONTAINER_NAME="VS-Server-${MINOR}"
# Replace any characters that might cause issues in container names (e.g., '/')
CONTAINER_NAME="${CONTAINER_NAME//\//-}"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "A container named '$CONTAINER_NAME' already exists."
    echo "Options:"
    echo "  [r] Remove the existing container and create a new one"
    echo "  [s] Stop and remove the existing container, then create new"
    echo "  [c] Enter a custom name for the new container"
    echo "  [q] Quit without changes"
    read -r -p "Choose [r/s/c/q]: " choice
    case "$choice" in
        r|R)
            echo "Removing existing container '$CONTAINER_NAME'..."
            docker rm -f "$CONTAINER_NAME"
            ;;
        s|S)
            echo "Stopping and removing existing container '$CONTAINER_NAME'..."
            docker stop "$CONTAINER_NAME" 2>/dev/null || true
            docker rm "$CONTAINER_NAME"
            ;;
        c|C)
            while true; do
                read -r -p "Enter custom container name: " custom_name
                # Basic validation: only letters, numbers, underscores, hyphens, dots
                if [[ ! "$custom_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                    echo "Invalid name. Use only letters, numbers, underscores, hyphens, and dots. Start with a letter or number."
                    continue
                fi
                if docker ps -a --format '{{.Names}}' | grep -q "^${custom_name}$"; then
                    echo "A container named '$custom_name' already exists. Choose a different name."
                    continue
                fi
                CONTAINER_NAME="$custom_name"
                break
            done
            ;;
        *)
            echo "Exiting. No changes made."
            exit 0
            ;;
    esac
fi

echo "Starting container '$CONTAINER_NAME' in detached mode..."
docker run -d --name "$CONTAINER_NAME" "$IMAGE_TAG"

# Provide post-deployment instructions
echo ""
echo "============================================================"
echo "Container '$CONTAINER_NAME' is now running in the background."
echo ""
echo "Useful Docker commands:"
echo "  docker ps                      - List running containers"
echo "  docker stop $CONTAINER_NAME    - Stop the container"
echo "  docker start $CONTAINER_NAME   - Start the container again"
echo "  docker logs $CONTAINER_NAME    - View container logs"
echo "  docker exec -it $CONTAINER_NAME /bin/sh  - Open a shell inside the container (if supported)"
echo "  docker rm -f $CONTAINER_NAME   - Remove the container entirely"
echo "============================================================"