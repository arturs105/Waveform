import Foundation

/// Scales amplitude values based on transient weight for visualization.
enum TransientScaler {
    /// Minimum amplitude multiplier for non-transient samples
    static let nonTransientAttenuation: Float = 0.15

    /// Power curve exponent for transient emphasis (higher = more compression)
    static let transientExpansionExponent: Float = 1.5

    /// Scales amplitude based on transient weight.
    /// - Parameters:
    ///   - amplitude: Original amplitude value (-1 to 1)
    ///   - weight: Transient weight (0 = no transient, 1 = strong transient)
    /// - Returns: Scaled amplitude value
    static func scaleAmplitude(_ amplitude: Float, weight: Float) -> Float {
        // Two-part scaling:
        // 1. Attenuate non-transients (low weight → smaller amplitude)
        // 2. Compress dynamic range for transients (high weight → values pulled toward 1.0)

        let attenuation = nonTransientAttenuation + weight * (1.0 - nonTransientAttenuation)

        // Power curve: compresses dynamic range, making transients more visible
        let scaleFactor = 1.0 / (1.0 + weight * transientExpansionExponent)
        let absAmp = abs(amplitude)
        let expanded = pow(absAmp, scaleFactor)

        let scaled = expanded * attenuation
        return amplitude >= 0 ? scaled : -scaled
    }
}
