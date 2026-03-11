package moderation

// TODO make dynamic cfg
type Thresholds struct {
	Toxic          float64
	Obscene        float64
	Threat         float64
	Insult         float64
	IdentityAttack float64
	SexualExplicit float64
}

func DefaultThresholds() Thresholds {
	return Thresholds{
		Toxic:          0.8,
		Obscene:        0.8,
		Threat:         0.8,
		Insult:         0.8,
		IdentityAttack: 0.8,
		SexualExplicit: 0.8,
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
	case s.IdentityAttack > t.IdentityAttack:
		return TextDecision{Block: true, Reason: "identity_attack"}
	case s.Insult > t.Insult:
		return TextDecision{Block: true, Reason: "insult"}
	case s.SexualExplicit > t.SexualExplicit:
		return TextDecision{Block: true, Reason: "sexual_explicit"}
	}
	return TextDecision{}
}
