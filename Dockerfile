# H3 Image en serverless — ComfyUI 0.45.0 + le nœud MiniMaxH3ImageConditioning.
#
# Pourquoi partir de l'image du template de pod : aucune image officielle
# runpod/worker-comfyui n'embarque MiniMax H3 Image (ni son nœud, qui exige
# ComfyUI >= 0.45.0). L'image v13 contient exactement le ComfyUI 0.45.0 et le
# jeu de nœuds qu'on a validés sur le pod. On lui greffe le handler serverless
# officiel au lieu de repartir de zéro et de devoir tout réépingler.
#
# Les POIDS ne sont pas dans l'image : ils vivent sur le volume réseau, monté
# en /runpod-volume et lu via extra_model_paths.yaml (voir RUNPOD).
FROM hearmeman/comfyui-minimax-template:v13

# Le template installe ComfyUI dans /ComfyUI (majuscule) ; le handler du worker
# le cherche dans /comfyui (minuscule). Sur un FS sensible à la casse ce sont
# deux chemins différents — sans ce lien, /comfyui/main.py n'existe pas.
RUN ln -sfn /ComfyUI /comfyui

# Handler serverless officiel (runpod-workers/worker-comfyui, Apache-2.0).
# start.sh lance ComfyUI puis le handler ; network_volume.py déclare les
# chemins du volume réseau.
COPY handler.py network_volume.py start.sh requirements.txt ./
# Le bit exécutable peut se perdre en route (il l'a fait) : on le remet ici,
# sans dépendre de ce que le dépôt transporte.
RUN chmod +x /start.sh

# CHEMIN EXPLICITE, volontairement : ComfyUI ne charge extra_model_paths.yaml
# que depuis SON dossier. L'officiel fait `WORKDIR /comfyui` puis `ADD ./`, ce
# qui dépend du WORKDIR de l'image de base — nous, on écrit le chemin en dur,
# sinon le fichier peut atterrir à la racine et n'être jamais lu.
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml
RUN pip install --no-cache-dir -r requirements.txt

# On REMPLACE le CMD du template (/start_script.sh, un script de pod qui
# synchronise deux dépôts et lance Jupyter + ComfyUI en interactif) : en
# serverless il n'y a ni Jupyter ni provisionnement à faire, les poids sont
# déjà sur le volume.
CMD ["/start.sh"]
