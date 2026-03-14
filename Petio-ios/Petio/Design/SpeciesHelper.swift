//
//  SpeciesHelper.swift
//  Petio
//
//  Maps species names to xcassets icon names.
//

import Foundation

/// Returns the xcassets image name for a given species string.
/// Falls back to "paw" for unknown species.
func speciesImageName(_ species: String) -> String {
    switch species {
    case "Собака":    return "dog"
    case "Кошка":    return "cat"
    case "Попугай":  return "parrot"
    case "Птица":    return "parrot"
    case "Кролик":   return "rabbit"
    case "Рыбка":    return "fish"
    case "Хомяк":    return "humster"
    case "Змея":     return "snake"
    case "Черепаха": return "turtle"
    case "Ящерица":  return "lizard"
    case "Ёж":       return "hedgehog"
    case "Сурикат":  return "meerkat"
    default:         return "paw"
    }
}
