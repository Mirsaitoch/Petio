"""
Константы для модерации контента.
Лейблы оптимизированы для CLIP и специфики pet-соцсети.
"""

# --- Text toxicity classes ---
CLASSES_NAME = [
    "toxicity",
    "severe_toxicity",
    "obscene",
    "threat",
    "insult",
    "identity_attack",
    "sexual_explicit",
]

# --- Image classification labels (для CLIP) ---
# Порядок важен - должен совпадать с порядком при инференсе
LABELS = [
    # Safe content
    "cute pet photo",
    "happy dog playing",
    "cat sleeping peacefully",
    "pet portrait",
    "animal with loving owner",
    
    # Medical context (не abuse!)
    "veterinary clinic",
    "animal surgery",
    "pet with bandage",
    "animal medical care",
    
    # Porn/NSFW
    "pornographic image",
    "explicit sexual content",
    "bestiality",
    "zoophilia",
    
    # Violence
    "dead animal with blood",
    "animal corpse",
    "roadkill photo",
    "mutilated animal",
    
    # Abuse
    "person hitting an animal",
    "dogfighting",
    "cockfighting",
    "animal cruelty",
    "trapped suffering animal",
]

# --- Label groups for scoring ---
SAFE_LABELS = [
    "cute pet photo",
    "happy dog playing",
    "cat sleeping peacefully",
    "pet portrait",
    "animal with loving owner",
]

MEDICAL_LABELS = [
    "veterinary clinic",
    "animal surgery",
    "pet with bandage",
    "animal medical care",
]

PORN_LABELS = [
    "pornographic image",
    "explicit sexual content",
    "bestiality",
    "zoophilia",
]

VIOLENCE_LABELS = [
    "dead animal with blood",
    "animal corpse",
    "roadkill photo",
    "mutilated animal",
]

ABUSE_LABELS = [
    "person hitting an animal",
    "dogfighting",
    "cockfighting",
    "animal cruelty",
    "trapped suffering animal",
]