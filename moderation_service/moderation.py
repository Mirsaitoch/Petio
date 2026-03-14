"""
Логика модерации контента для pet-соцсети.
Поддерживает три уровня решений: allow, review, block.
"""

from dataclasses import dataclass
from enum import Enum
from typing import Optional, Any

from constants import (
    SAFE_LABELS,
    MEDICAL_LABELS,
    PORN_LABELS,
    VIOLENCE_LABELS,
    ABUSE_LABELS,
)


# --- Enums ---

class ModerationAction(str, Enum):
    ALLOW = "allow"
    REVIEW = "review"
    BLOCK = "block"


class BlockReason(str, Enum):
    PORNOGRAPHIC = "pornographic_content"
    VIOLENCE = "graphic_violence"
    ANIMAL_ABUSE = "animal_abuse"
    NSFW_GENERAL = "nsfw_general"
    UNCLASSIFIABLE = "unclassifiable_content"


# --- Thresholds ---

@dataclass
class ImageThresholds:
    """Пороги для модерации изображений."""
    
    # NSFW classifier
    nsfw_block: float = 0.75
    nsfw_review: float = 0.50
    
    # Porn (CLIP)
    porn_block: float = 0.70
    porn_review: float = 0.4
    
    # Violence (CLIP)
    violence_block: float = 0.40
    violence_review: float = 0.25
    
    # Abuse (CLIP)
    abuse_block: float = 0.35
    abuse_review: float = 0.20
    
    # Context modifiers
    safe_boost_threshold: float = 0.30
    medical_context_threshold: float = 0.35
    pet_content_threshold: float = 0.25
    
    # Adversarial protection
    min_confidence_threshold: float = 0.12
    
    # Multipliers
    nsfw_pet_discount: float = 0.6  # NSFW score × 0.6 для pet-контента
    medical_violence_boost: float = 1.4  # Violence threshold × 1.4 для медицины


@dataclass
class TextThresholds:
    """Пороги для модерации текста."""
    block: float = 0.75
    review: float = 0.50


# --- Default thresholds ---
IMAGE_THRESHOLDS = ImageThresholds()
TEXT_THRESHOLDS = TextThresholds()


# --- Score calculation ---

def _max_score(clip_result: dict[str, float], labels: list[str]) -> float:
    """Возвращает максимальный скор среди указанных лейблов."""
    scores = (clip_result.get(label, 0.0) for label in labels)
    return max(scores, default=0.0)


def calculate_category_scores(clip_result: dict[str, float]) -> dict[str, float]:
    """
    Агрегирует CLIP-скоры по категориям.
    Используем MAX вместо SUM, т.к. softmax даёт распределение.
    """
    return {
        "safe": _max_score(clip_result, SAFE_LABELS),
        "medical": _max_score(clip_result, MEDICAL_LABELS),
        "porn": _max_score(clip_result, PORN_LABELS),
        "violence": _max_score(clip_result, VIOLENCE_LABELS),
        "abuse": _max_score(clip_result, ABUSE_LABELS),
    }


# --- Image moderation ---
def moderate_image(
    nsfw_score: float,
    clip_result: dict[str, float],
    thresholds: ImageThresholds = IMAGE_THRESHOLDS,
) -> dict[str, Any]:
    """
    Принимает решение о модерации изображения.
    
    Args:
        nsfw_score: Скор от NSFW-классификатора [0, 1]
        clip_result: Словарь {label: score} от CLIP
        thresholds: Пороги для принятия решений
    
    Returns:
        {
            "action": "allow" | "review" | "block",
            "blocked": bool,
            "needs_review": bool,
            "reason": str | None,
            "confidence": float,
            "scores": {category: score},
            "meta": {debug info}
        }
    """
    scores = calculate_category_scores(clip_result)
    
    # --- Контекстные флаги ---
    is_likely_safe = scores["safe"] > thresholds.safe_boost_threshold
    is_medical_context = scores["medical"] > thresholds.medical_context_threshold
    is_pet_content = scores["safe"] > thresholds.pet_content_threshold
    
    # --- Корректировки ---
    
    # NSFW-модель обучена на людях, менее надёжна для животных
    effective_nsfw = nsfw_score
    if is_pet_content:
        effective_nsfw *= thresholds.nsfw_pet_discount
    
    # Медицинский контекст смягчает violence (ветеринар ≠ насилие)
    effective_violence_threshold = thresholds.violence_block
    if is_medical_context:
        effective_violence_threshold *= thresholds.medical_violence_boost
    
    # --- Принятие решения ---
    action = ModerationAction.ALLOW
    reason: Optional[BlockReason] = None
    confidence = 0.0
    
    # 1. Порнография — высший приоритет
    if scores["porn"] > thresholds.porn_block:
        action = ModerationAction.BLOCK
        reason = BlockReason.PORNOGRAPHIC
        confidence = scores["porn"]
    
    # 2. Насилие над животными
    elif scores["abuse"] > thresholds.abuse_block:
        action = ModerationAction.BLOCK
        reason = BlockReason.ANIMAL_ABUSE
        confidence = scores["abuse"]
    
    # 3. Графическое насилие (с учётом медицинского контекста)
    elif scores["violence"] > effective_violence_threshold:
        action = ModerationAction.BLOCK
        reason = BlockReason.VIOLENCE
        confidence = scores["violence"]
    
    # 4. NSFW + подозрение на порно
    elif effective_nsfw > thresholds.nsfw_block and scores["porn"] > 0.15:
        action = ModerationAction.BLOCK
        reason = BlockReason.NSFW_GENERAL
        confidence = effective_nsfw
    
    # --- Review для пограничных случаев ---
    if action == ModerationAction.ALLOW:
        if scores["porn"] > thresholds.porn_review:
            action = ModerationAction.REVIEW
            reason = BlockReason.PORNOGRAPHIC
            confidence = scores["porn"]
        
        elif scores["abuse"] > thresholds.abuse_review:
            action = ModerationAction.REVIEW
            reason = BlockReason.ANIMAL_ABUSE
            confidence = scores["abuse"]
        
        elif scores["violence"] > thresholds.violence_review:
            action = ModerationAction.REVIEW
            reason = BlockReason.VIOLENCE
            confidence = scores["violence"]
        
        elif effective_nsfw > thresholds.nsfw_review:
            action = ModerationAction.REVIEW
            reason = BlockReason.NSFW_GENERAL
            confidence = effective_nsfw
    
    # --- Защита от adversarial ---
    # Если CLIP не смог классифицировать — подозрительно
    max_clip_score = max(clip_result.values()) if clip_result else 0.0
    
    if max_clip_score < thresholds.min_confidence_threshold:
        if action == ModerationAction.ALLOW:
            action = ModerationAction.REVIEW
            reason = BlockReason.UNCLASSIFIABLE
            confidence = max_clip_score
    
    # --- Формируем ответ ---
    return {
        "action": action.value,
        "blocked": action == ModerationAction.BLOCK,
        "needs_review": action == ModerationAction.REVIEW,
        "reason": reason.value if reason else None,
        "confidence": round(confidence, 4),
        "scores": {
            "nsfw": round(nsfw_score, 4),
"safe": round(scores["safe"], 4),
            "medical": round(scores["medical"], 4),
            "porn": round(scores["porn"], 4),
            "violence": round(scores["violence"], 4),
            "abuse": round(scores["abuse"], 4),
        },
        "meta": {
            "effective_nsfw": round(effective_nsfw, 4),
            "effective_violence_threshold": round(effective_violence_threshold, 4),
            "is_pet_content": is_pet_content,
            "is_medical_context": is_medical_context,
            "is_likely_safe": is_likely_safe,
            "max_clip_score": round(max_clip_score, 4),
        },
    }


# --- Text moderation ---

def moderate_text(
    scores: dict[str, float],
    thresholds: TextThresholds = TEXT_THRESHOLDS,
) -> dict[str, Any]:
    """
    Принимает решение о модерации текста.
    
    Args:
        scores: Словарь {category: score} от toxicity-модели
        thresholds: Пороги для принятия решений
    
    Returns:
        {
            "action": "allow" | "review" | "block",
            "blocked": bool,
            "needs_review": bool,
            "reason": str | None,
            "confidence": float,
            "scores": {category: score}
        }
    """
    if not scores:
        return {
            "action": ModerationAction.ALLOW.value,
            "blocked": False,
            "needs_review": False,
            "reason": None,
            "confidence": 0.0,
            "scores": {},
        }
    
    # Находим категорию с максимальным скором
    max_category = max(scores, key=scores.get)
    max_score = scores[max_category]
    
    action = ModerationAction.ALLOW
    reason: Optional[str] = None
    confidence = 0.0
    
    if max_score > thresholds.block:
        action = ModerationAction.BLOCK
        reason = max_category
        confidence = max_score
    
    elif max_score > thresholds.review:
        action = ModerationAction.REVIEW
        reason = max_category
        confidence = max_score
    
    return {
        "action": action.value,
        "blocked": action == ModerationAction.BLOCK,
        "needs_review": action == ModerationAction.REVIEW,
        "reason": reason,
        "confidence": round(confidence, 4),
        "scores": {k: round(v, 4) for k, v in scores.items()},
    }