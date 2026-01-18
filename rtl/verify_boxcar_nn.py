#!/usr/bin/env python3
"""
Verification script to compare RTL simulation results with Python model
"""

import numpy as np
import subprocess
import os

# True weights from trained model
true_weights = {
    'W1_11': 7.0, 'W1_21': -5.0, 'b1_1': 5.0, 'b1_2': 5.0,
    'W2_11': 1.0, 'W2_12': 1.0, 'W2_21': 1.0, 'W2_22': 1.0,
    'W2_31': 3.0, 'W2_32': -3.0, 'b2_1': 0.5, 'b2_2': 0.5, 'b2_3': -2.0,
    'W3_11': 2.0, 'W3_12': 2.0, 'W3_13': 3.0, 'b3_1': 0.0
}

def true_forward(x):
    """Python reference model"""
    h1_1 = np.tanh(true_weights['W1_11'] * x + true_weights['b1_1'])
    h1_2 = np.tanh(true_weights['W1_21'] * x + true_weights['b1_2'])
    h2_1 = np.tanh(true_weights['W2_11'] * h1_1 + true_weights['W2_12'] * h1_2 + true_weights['b2_1'])
    h2_2 = np.tanh(true_weights['W2_21'] * h1_1 + true_weights['W2_22'] * h1_2 + true_weights['b2_2'])
    h2_3 = np.tanh(true_weights['W2_31'] * h1_1 + true_weights['W2_32'] * h1_2 + true_weights['b2_3'])
    return true_weights['W3_11'] * h2_1 + true_weights['W3_12'] * h2_2 + true_weights['W3_13'] * h2_3 + true_weights['b3_1']

def run_rtl_simulation():
    """Run iverilog simulation and capture output"""
    print("Compiling RTL with iverilog...")
    
    # Compile
    compile_cmd = [
        'iverilog',
        '-g2012',  # SystemVerilog support
        '-o', 'boxcar_nn_sim',
        'boxcar_nn.sv',
        'boxcar_nn_tb.sv'
    ]
    
    try:
        result = subprocess.run(compile_cmd, capture_output=True, text=True, check=True)
        print("✓ Compilation successful")
    except subprocess.CalledProcessError as e:
        print(f"✗ Compilation failed:\n{e.stderr}")
        return None
    except FileNotFoundError:
        print("✗ iverilog not found. Install with: brew install icarus-verilog")
        return None
    
    # Run simulation
    print("Running simulation...")
    try:
        result = subprocess.run(['./boxcar_nn_sim'], capture_output=True, text=True, check=True)
        print("✓ Simulation completed")
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"✗ Simulation failed:\n{e.stderr}")
        return None

def parse_simulation_output(output):
    """Parse simulation output to extract test results"""
    results = []
    for line in output.split('\n'):
        if 'x =' in line and 'y =' in line:
            # Parse line like: "x =  1.000 | y =  2.5000 | LEDs = 111100 | y_fixed = 2560"
            parts = line.split('|')
            try:
                x_val = float(parts[0].split('=')[1].strip())
                y_val = float(parts[1].split('=')[1].strip())
                results.append((x_val, y_val))
            except:
                continue
    return results

def compare_results(rtl_results):
    """Compare RTL results with Python model"""
    print("\n" + "="*70)
    print("Verification Results")
    print("="*70)
    print(f"{'Input (x)':<12} {'Python y':<12} {'RTL y':<12} {'Error':<12} {'Status'}")
    print("-"*70)
    
    max_error = 0.0
    errors = []
    
    for x_val, y_rtl in rtl_results:
        y_python = true_forward(x_val)
        error = abs(y_python - y_rtl)
        max_error = max(max_error, error)
        errors.append(error)
        
        status = "✓ PASS" if error < 0.5 else "✗ FAIL"
        print(f"{x_val:>11.3f}  {y_python:>11.4f}  {y_rtl:>11.4f}  {error:>11.4f}  {status}")
    
    print("-"*70)
    print(f"Max Error: {max_error:.4f}")
    print(f"Mean Error: {np.mean(errors):.4f}")
    print(f"RMS Error: {np.sqrt(np.mean(np.array(errors)**2)):.4f}")
    print("="*70)
    
    if max_error < 0.5:
        print("\n✓ Verification PASSED - RTL matches Python model!")
    else:
        print("\n✗ Verification FAILED - Errors exceed threshold")
    
    return max_error < 0.5

def generate_test_data_file():
    """Generate test data file for manual testing"""
    x_test = np.linspace(-3, 3, 20)
    y_test = np.array([true_forward(x) for x in x_test])
    
    with open('boxcar_test_data.txt', 'w') as f:
        f.write("# Test data for boxcar neural network\n")
        f.write("# Format: x_input, y_expected\n")
        for x, y in zip(x_test, y_test):
            f.write(f"{x:.6f}, {y:.6f}\n")
    
    print(f"\n✓ Test data saved to 'boxcar_test_data.txt'")

if __name__ == "__main__":
    print("="*70)
    print("Boxcar Neural Network RTL Verification")
    print("="*70)
    
    # Change to rtl directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(script_dir)
    
    # Generate test data
    generate_test_data_file()
    
    # Run RTL simulation
    output = run_rtl_simulation()
    
    if output:
        # Parse results
        rtl_results = parse_simulation_output(output)
        
        if rtl_results:
            # Compare with Python model
            passed = compare_results(rtl_results)
            
            # Generate plot
            print("\nGenerating comparison plot...")
            try:
                import matplotlib.pyplot as plt
                
                x_vals = [r[0] for r in rtl_results]
                y_rtl = [r[1] for r in rtl_results]
                y_python = [true_forward(x) for x in x_vals]
                
                x_plot = np.linspace(-4, 4, 200)
                y_plot = np.array([true_forward(x) for x in x_plot])
                
                plt.figure(figsize=(12, 6))
                plt.plot(x_plot, y_plot, 'b-', linewidth=2, label='Python Model')
                plt.scatter(x_vals, y_python, c='blue', s=100, marker='o', 
                           edgecolors='darkblue', linewidth=2, label='Python Test Points', zorder=5)
                plt.scatter(x_vals, y_rtl, c='red', s=60, marker='x', 
                           linewidth=3, label='RTL Simulation', zorder=6)
                
                plt.xlabel('Input (x)', fontsize=12)
                plt.ylabel('Output (y)', fontsize=12)
                plt.title('Boxcar NN: Python vs RTL Verification', fontsize=14, fontweight='bold')
                plt.legend(fontsize=10)
                plt.grid(True, alpha=0.3)
                plt.axhline(y=0, color='gray', linestyle='--', linewidth=0.5)
                plt.axvline(x=0, color='gray', linestyle='--', linewidth=0.5)
                
                plt.tight_layout()
                plt.savefig('boxcar_nn_verification.png', dpi=150)
                print("✓ Plot saved to 'boxcar_nn_verification.png'")
                
            except ImportError:
                print("matplotlib not available, skipping plot generation")
        else:
            print("✗ No results parsed from simulation output")
    else:
        print("\n✗ Simulation failed - cannot verify")
        print("\nNote: This script requires iverilog (Icarus Verilog)")
        print("Install on Mac: brew install icarus-verilog")
