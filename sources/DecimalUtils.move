module projectOwnerAdr::DecimalUtils {
    /// A struct to represent decimal values
    struct Decimal {
        value: u64,  // The scaled integer value
        scale: u8,   // Number of decimal places
    }

    /// Creates a Decimal value
    public fun create(value: u64, scale: u8): Decimal {
        Decimal { value, scale }
    }

    /// Converts a Decimal back to its floating-point representation as a string
    public fun to_string(decimal: &Decimal): String {
        let divisor = pow(10, decimal.scale);
        let integer_part = decimal.value / divisor;
        let fractional_part = decimal.value % divisor;
        str::concat(
            str::concat(integer_part, b"."),
            fractional_part
        )
    }

    /// Adds two Decimal values
    public fun add(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let sum = dec1.value + dec2.value;
        Decimal { value: sum, scale: dec1.scale }
    }

    /// Subtracts two Decimal values
    public fun subtract(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let difference = dec1.value - dec2.value;
        Decimal { value: difference, scale: dec1.scale }
    }

    /// Multiplies two Decimal values
    public fun multiply(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let product = (dec1.value * dec2.value) / pow(10, dec1.scale);
        Decimal { value: product, scale: dec1.scale }
    }

    /// Divides two Decimal values
    public fun divide(dec1: &Decimal, dec2: &Decimal): Decimal {
        assert!(dec1.scale == dec2.scale, 1);  // Ensure both decimals have the same scale
        let quotient = (dec1.value * pow(10, dec1.scale)) / dec2.value;
        Decimal { value: quotient, scale: dec1.scale }
    }

    /// Helper function to compute powers of 10
    fun pow(base: u64, exponent: u8): u64 {
        let result = 1;
        let count = 0;
        while (count < exponent) {
            result = result * base;
            count = count + 1;
        }
        result
    }
}
