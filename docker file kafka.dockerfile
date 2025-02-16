# Utilisation de l'image Python de base
FROM python:3.9-slim

# Définition du répertoire de travail dans le container
WORKDIR /app

# Copier le fichier requirements.txt dans le container
COPY requirements.txt requirements.txt

# Installer les dépendances listées dans requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copier tous les fichiers dans le répertoire de travail
COPY . .

# Lancer le fichier consumer.py (pour consumer) ou producer.py (pour producer) selon le service
CMD ["python", "consumer.py"]
