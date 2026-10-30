#!/usr/bin/env bash
# deploy.sh : copie mod/phil_chronicles dans le dossier staging du jeu et vérifie les sha256.
# Usage : tools/deploy.sh [--skip-tests] [--zip vN]   (TF3_STAGING remplace la cible par défaut)
# Lance d'abord `lua tests/run.lua` (sauté avec --skip-tests) ; --zip vN crée .build/phil_chronicles_vN.zip.
set -u
set -o pipefail

MOD_NAME="phil_chronicles"
SKIP_TESTS=0
ZIP_VER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-tests)
      SKIP_TESTS=1
      shift ;;
    --zip)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "Erreur : --zip attend une version (ex. v2)." >&2
        exit 2
      fi
      ZIP_VER="$2"
      shift 2 ;;
    -h|--help)
      echo "Usage : $0 [--skip-tests] [--zip vN]"
      exit 0 ;;
    *)
      echo "Option inconnue : $1" >&2
      exit 2 ;;
  esac
done

if [ -n "$ZIP_VER" ] && ! [[ "$ZIP_VER" =~ ^v[0-9A-Za-z._-]+$ ]]; then
  echo "Erreur : version invalide '$ZIP_VER' (attendu vN, ex. v2)." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)" || exit 1
cd "$ROOT" || exit 1

SRC="$ROOT/mod/$MOD_NAME"
STAGING="${TF3_STAGING:-/c/Program Files (x86)/Steam/userdata/195775244/3493540/local/staging_area}"
DEST="$STAGING/$MOD_NAME"

# 1. Tests
if [ "$SKIP_TESTS" -eq 0 ]; then
  echo "Tests : lua tests/run.lua"
  TEST_OUT="$(lua tests/run.lua 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "Échec des tests (code $rc). Dernières lignes :" >&2
    printf '%s\n' "$TEST_OUT" | tail -n 5 >&2
    echo "Déploiement annulé." >&2
    exit 1
  fi
  echo "Tests OK."
else
  echo "Tests ignorés (--skip-tests)."
fi

# Vérifications avant écriture
if [ ! -d "$SRC" ]; then
  echo "Source introuvable : $SRC" >&2
  exit 1
fi
if [ ! -d "$STAGING" ]; then
  echo "Dossier staging introuvable : $STAGING" >&2
  exit 1
fi
if [ "$(basename "$DEST")" != "$MOD_NAME" ]; then
  echo "Cible invalide : $DEST" >&2
  exit 1
fi

# 2. Suppression de l'ancienne version puis copie (sans *.bak)
echo "Suppression de l'ancienne version..."
if ! rm -rf -- "${DEST:?}"; then
  echo "Échec de la suppression de $DEST" >&2
  exit 1
fi
mkdir -p -- "$DEST" || { echo "Échec de création de $DEST" >&2; exit 1; }

echo "Copie vers $DEST ..."
if ! (cd "$SRC" && tar --exclude='*.bak' -cf - .) | (cd "$DEST" && tar -xf -); then
  echo "Échec de la copie." >&2
  exit 1
fi

# 3. Vérification sha256 fichier par fichier
echo "Vérification sha256..."
n=0
bad=()
while IFS= read -r -d '' f; do
  n=$((n + 1))
  rel="${f#./}"
  hs="$(sha256sum -- "$SRC/$rel" 2>/dev/null | cut -d' ' -f1)"
  ht="$(sha256sum -- "$DEST/$rel" 2>/dev/null | cut -d' ' -f1)"
  if [ -z "$hs" ] || [ "$hs" != "$ht" ]; then
    bad+=("$rel")
  fi
done < <(cd "$SRC" && find . -type f ! -name '*.bak' -print0)

nd="$(find "$DEST" -type f | wc -l | tr -d ' ')"

if [ "${#bad[@]}" -gt 0 ] || [ "$nd" -ne "$n" ]; then
  echo "Échec : ${#bad[@]} fichier(s) différent(s) :" >&2
  for b in "${bad[@]}"; do
    echo "  - $b" >&2
  done
  if [ "$nd" -ne "$n" ]; then
    echo "  nombre de fichiers : source $n, cible $nd" >&2
  fi
  exit 1
fi
echo "OK $n fichiers"

# 4. Zip optionnel (copie filtrée des *.bak dans un dossier temporaire)
if [ -n "$ZIP_VER" ]; then
  OUT_DIR="$ROOT/.build"
  mkdir -p -- "$OUT_DIR" || exit 1
  ZIP="$OUT_DIR/${MOD_NAME}_${ZIP_VER}.zip"
  STAGE="$(mktemp -d "$OUT_DIR/stage.XXXXXX")" || exit 1
  mkdir -p -- "$STAGE/$MOD_NAME" || exit 1
  if ! (cd "$SRC" && tar --exclude='*.bak' -cf - .) | (cd "$STAGE/$MOD_NAME" && tar -xf -); then
    rm -rf -- "${STAGE:?}"
    echo "Échec de la préparation du zip." >&2
    exit 1
  fi

  rm -f -- "$ZIP"
  echo "Création de $ZIP ..."
  if command -v zip >/dev/null 2>&1; then
    (cd "$STAGE" && zip -qr "$ZIP" "$MOD_NAME")
    zrc=$?
  else
    powershell.exe -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$STAGE/$MOD_NAME")' -DestinationPath '$(cygpath -w "$ZIP")' -Force"
    zrc=$?
  fi
  rm -rf -- "${STAGE:?}"

  if [ "$zrc" -ne 0 ] || [ ! -f "$ZIP" ]; then
    echo "Échec de la création du zip." >&2
    exit 1
  fi
  echo "Zip : $ZIP"
fi

echo "Déploiement terminé : $DEST"
