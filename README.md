# Serverless H3 Image — conception

Objectif : un endpoint RunPod qui prend un graphe ComfyUI + des images de
référence et rend des images, sans pod à maintenir.

## Pièces

1. **Le dépôt** (ce dossier) — `Dockerfile` + le handler officiel de
   `runpod-workers/worker-comfyui` (Apache-2.0, à créditer). RunPod sait
   **construire l'image depuis un dépôt GitHub** : pas besoin de registre, ce
   qui contourne l'absence de portée `write:packages` sur le jeton `gh`.
2. **Le volume réseau** — les poids, en `/runpod-volume/models/...`. Le worker
   les déclare par `extra_model_paths.yaml` et les détecte automatiquement.
3. **L'endpoint** — image construite + volume attaché.

## Ce qui est établi

- Requête : `input.workflow` (graphe au format API) + `input.images`
  (`[{name, image: base64}]`). Le worker dépose chaque image dans le `input` de
  ComfyUI, où le graphe la référence par son `name`.
- **Le graphe doit utiliser la forme plate et pointée** `"images.image_1":
  ["charge_1", 0]` — c'est la sérialisation de l'autogrow, vérifiée par
  contrôle positif. Un dictionnaire imbriqué est ignoré **en silence**.
- 21 photos ≈ 4,55 Mo en base64 : sous les limites de `/run` (10 Mo) et de
  `/runsync` (20 Mo).
- `COMFYUI_DIR` du template = `/ComfyUI` ; le worker attend `/comfyui` → lien
  symbolique créé dans le Dockerfile.

## Risque à lever pendant le build

Le runtime du template symlinke `models`, `user`, `output`, `input` de
`/ComfyUI` vers le volume persistant du pod (`/workspace/...`). Si l'image
contient de tels liens en dur, en serverless ils pendent (pas de `/workspace`).
Les chemins du volume réseau sont ajoutés par `extra_model_paths.yaml`, donc
ComfyUI devrait malgré tout trouver les modèles — **à confirmer au premier
test**, en lisant les journaux du worker si un modèle manque.

## Poids : deux jeux possibles

| | DiT | Encodeur | VAE | Total |
|---|---|---|---|---|
| int8 (validé sur pod) | 20,98 | 27,14 | 1,17 | **49,3 Go** |
| w4a8 + nvfp4 | 12,55 | 15,69 | 1,17 | **29,4 Go** |

Le second n'est pas encore validé en qualité : `minimax_h3_image_pruned_w4a8`
et `qwen3vl_32b_minimax_h3_nvfp4_awq` existent sur
`Comfy-Org/MiniMax-H3-Image`, mais le registre du template ne les connaît pas.
Changer de jeu plus tard = remplacer des fichiers dans le volume, pas
reconstruire l'image.
