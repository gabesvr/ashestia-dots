#!/usr/bin/env bash
# Roda a cada abertura de terminal — seleciona a próxima imagem da pasta Goticas
# em sequência circular e copia para .current_fetch.jpg

GOTICAS_DIR="$HOME/Pictures/Goticas"
STATE_FILE="$GOTICAS_DIR/.fetch_index"
OUTPUT="$GOTICAS_DIR/.current_fetch.jpg"

# Lista de imagens (ordenada)
mapfile -t IMAGES < <(find "$GOTICAS_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | sort)

if [ ${#IMAGES[@]} -eq 0 ]; then
    exit 0
fi

# Lê o índice atual, incrementa
INDEX=0
if [ -f "$STATE_FILE" ]; then
    INDEX=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
fi

# Seleciona a imagem e avança o índice
SELECTED="${IMAGES[$INDEX]}"
NEXT_INDEX=$(( (INDEX + 1) % ${#IMAGES[@]} ))
echo "$NEXT_INDEX" > "$STATE_FILE"

# Copia para o arquivo de saída (evita problemas com symlinks e sixel)
cp -f "$SELECTED" "$OUTPUT"
