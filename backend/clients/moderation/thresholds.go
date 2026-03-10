package moderation

type Thresholds struct {
	Toxic        float64
	Obscene      float64
	Threat       float64
	Insult       float64
	IdentityHate float64
}

func DefaultThresholds() Thresholds {
	return Thresholds{
		Toxic:        0.7,
		Obscene:      0.7,
		Threat:       0.7,
		Insult:       0.8,
		IdentityHate: 0.7,
	}
}

type TextDecision struct {
	Block  bool
	Reason string
}

func (t Thresholds) Evaluate(s *TextScores) TextDecision {
	switch {
	case s.Toxic > t.Toxic:
		return TextDecision{Block: true, Reason: "toxic_content"}
	case s.Obscene > t.Obscene:
		return TextDecision{Block: true, Reason: "obscene_content"}
	case s.Threat > t.Threat:
		return TextDecision{Block: true, Reason: "threat"}
	case s.IdentityHate > t.IdentityHate:
		return TextDecision{Block: true, Reason: "identity_hate"}
	case s.Insult > t.Insult:
		return TextDecision{Block: true, Reason: "insult"}
	}
	return TextDecision{}
}
