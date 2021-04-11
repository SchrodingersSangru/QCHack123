namespace QCHack.Task1 {
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arithmetic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Preparation;


    // Task 1 (1 point). f(x) = 1 if x is divisible by 4
    //         
    // Inputs:
    //      1) an N-qubit array "inputs" (3 ≤ N ≤ 5),
    //      2) a qubit "output".
    // Goal: Implement a marking oracle for function f(x) = 1 if x is divisible by 4.
    //       That is, if both inputs are in a basis state, flip the state of the output qubit 
    //       if and only if the number written in the array "inputs" is divisible by 4,
    //       and leave the state of the array "inputs" unchanged.
    //       The array "inputs" uses little-endian encoding, i.e., 
    //       the least significant bit of the integer is stored first.
    //       The effect of the oracle on superposition states should be defined by its linearity.
    //       Don't use measurements; the implementation should use only X gates and its controlled variants.
    //       This task will be tested using ToffoliSimulator.
    // 
    // Example: the result of applying the oracle to a state (|001⟩ + |100⟩ + |111⟩)/√3 ⊗ |0⟩
    // will be 1/√3|001⟩ ⊗ |1⟩ + 1/√3|100⟩ ⊗ |0⟩ + 1/√3|111⟩ ⊗ |0⟩.
    //
    operation Task1_DivisibleByFour (inputs : Qubit[], output : Qubit) : Unit is Adj+Ctl {

        // Define the oracle that for the factoring problem.
        let markingOracle = MarkDivisor(number, _, _);
        let phaseOracle = ApplyMarkingOracleAsPhaseOracle(markingOracle, _);
        // Bit-size of the number to factorize.
        let size = BitSizeI(number);
        // Estimate of the number of solutions.
        let nSolutions = x%4;
        // The number of iterations can be computed using the formula.
        let nIterations = Round(PI() / 4.0 * Sqrt(IntAsDouble(size) / IntAsDouble(nSolutions)));

        // Initialize the register to run the algorithm
        use (register, output) = (Qubit[size], Qubit());
        mutable isCorrect = false;
        mutable answer = 0;
        // Use a Repeat-Until-Succeed loop to iterate until the solution is valid.
        repeat {
            RunGroversSearch(register, phaseOracle, nIterations);
            let res = MultiM(register);
            set answer = BoolArrayAsInt(ResultArrayAsBoolArray(res));
            // Check that if the result is a solution with the oracle.
            markingOracle(register, output);
            if MResetZ(output) == One and answer != 1 and answer != number {
                set isCorrect = true;
            }
            ResetAll(register);
        } until isCorrect;

        // Print out the answer.
        Message($"The number {answer} is a factor of {number}.");

    }

    operation MarkDivisor (
        dividend : Int,
        divisorRegister : Qubit[],
        target : Qubit
    ) : Unit is Adj+Ctl {
        let size = BitSizeI(dividend);
        use (dividendQubits, resultQubits) = (Qubit[size], Qubit[size]);
        let xs = LittleEndian(dividendQubits);
        let ys = LittleEndian(divisorRegister);
        let result = LittleEndian(resultQubits);
        within{
            ApplyXorInPlace(dividend, xs);
            DivideI(xs, ys, result);
            ApplyToEachA(X, xs!);
        }
        apply{
            Controlled X(xs!, target);
        }
    }

    operation PrepareUniformSuperpositionOverDigits(digitReg : Qubit[]) : Unit is Adj + Ctl {
        PrepareArbitraryStateCP(ConstantArray(10, ComplexPolar(1.0, 0.0)), LittleEndian(digitReg));
    }

    operation ApplyMarkingOracleAsPhaseOracle(
        markingOracle : (Qubit[], Qubit) => Unit is Adj,
        register : Qubit[]
    ) : Unit is Adj {
        use target = Qubit();
        within {
            X(target);
            H(target);
        } apply {
            markingOracle(register, target);
        }
    }

    operation RunGroversSearch(register : Qubit[], phaseOracle : ((Qubit[]) => Unit is Adj), iterations : Int) : Unit {
        ApplyToEach(H, register);
        for _ in 1 .. iterations {
            phaseOracle(register);
            ReflectAboutUniform(register);
        }
    }

    operation ReflectAboutUniform(inputQubits : Qubit[]) : Unit {
        within {
            ApplyToEachA(H, inputQubits);
            ApplyToEachA(X, inputQubits);
        } apply {
            Controlled Z(Most(inputQubits), Tail(inputQubits));
        }
    }
}