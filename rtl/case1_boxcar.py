import numpy as np
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
import torch.optim as optim

# Neural Network with same architecture as boxcar_2layer
# Input(1) -> Hidden1(2) -> Hidden2(3) -> Output(1)
class BoxcarNN(nn.Module):
    def __init__(self):
        super(BoxcarNN, self).__init__()
        # Layer 1: input(1) -> hidden1(2)
        self.W1 = nn.Linear(1, 2, bias=True)
        # Layer 2: hidden1(2) -> hidden2(3)
        self.W2 = nn.Linear(2, 3, bias=True)
        # Layer 3: hidden2(3) -> output(1)
        self.W3 = nn.Linear(3, 1, bias=True)
        
    def forward(self, x):
        # Hidden layer 1 with tanh activation
        h1 = torch.tanh(self.W1(x))
        # Hidden layer 2 with tanh activation
        h2 = torch.tanh(self.W2(h1))
        # Output layer (no activation)
        y = self.W3(h2)
        return y
    
    def get_weights(self):
        """Return weights in the naming convention W1_11, W1_21, etc."""
        weights = {}
        # Layer 1 weights
        W1 = self.W1.weight.data.numpy()
        weights['W1_11'] = W1[0, 0]
        weights['W1_21'] = W1[1, 0]
        weights['b1_1'] = self.W1.bias.data.numpy()[0]
        weights['b1_2'] = self.W1.bias.data.numpy()[1]
        
        # Layer 2 weights
        W2 = self.W2.weight.data.numpy()
        weights['W2_11'] = W2[0, 0]
        weights['W2_12'] = W2[0, 1]
        weights['W2_21'] = W2[1, 0]
        weights['W2_22'] = W2[1, 1]
        weights['W2_31'] = W2[2, 0]
        weights['W2_32'] = W2[2, 1]
        weights['b2_1'] = self.W2.bias.data.numpy()[0]
        weights['b2_2'] = self.W2.bias.data.numpy()[1]
        weights['b2_3'] = self.W2.bias.data.numpy()[2]
        
        # Layer 3 weights
        W3 = self.W3.weight.data.numpy()
        weights['W3_11'] = W3[0, 0]
        weights['W3_12'] = W3[0, 1]
        weights['W3_13'] = W3[0, 2]
        weights['b3_1'] = self.W3.bias.data.numpy()[0]
        
        return weights


def load_data(filepath):
    """Load noisy data from CSV file."""
    data = np.loadtxt(filepath, delimiter=',', skiprows=1)
    x = data[:, 0].reshape(-1, 1)
    y = data[:, 1].reshape(-1, 1)
    return x, y


def generate_train_test_data(true_forward_func, n_points=100, noise_std=0.3, seed=42):
    """
    Dense uniform sampling with alternating train/test split.
    Generate data in [-3, 3] range and split alternately.
    """
    np.random.seed(seed)
    
    # Generate data in [-3, 3] range
    x_all = np.linspace(-3, 3, n_points)
    
    # Alternating split: even indices = train, odd indices = test
    train_indices = np.arange(0, len(x_all), 2)  # 0, 2, 4, 6, ...
    test_indices = np.arange(1, len(x_all), 2)   # 1, 3, 5, 7, ...
    
    x_train = x_all[train_indices]
    x_test = x_all[test_indices]
    
    # Compute true function values
    y_train_clean = true_forward_func(x_train)
    y_test_clean = true_forward_func(x_test)
    
    # Add Gaussian noise
    y_train = y_train_clean + np.random.normal(0, noise_std, size=y_train_clean.shape)
    y_test = y_test_clean + np.random.normal(0, noise_std, size=y_test_clean.shape)
    
    return (x_train.reshape(-1, 1), y_train.reshape(-1, 1), 
            x_test.reshape(-1, 1), y_test.reshape(-1, 1))


def train_model(model, x_train, y_train, epochs=2000, lr=0.01):
    """Train the neural network."""
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=lr)
    
    # Convert to tensors
    x_tensor = torch.FloatTensor(x_train)
    y_tensor = torch.FloatTensor(y_train)
    
    losses = []
    
    for epoch in range(epochs):
        # Forward pass
        y_pred = model(x_tensor)
        loss = criterion(y_pred, y_tensor)
        
        # Backward pass
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        losses.append(loss.item())
        
        if (epoch + 1) % 200 == 0:
            print(f'Epoch [{epoch+1}/{epochs}], Loss: {loss.item():.6f}')
    
    return losses


if __name__ == "__main__":
    # True weights from boxcar_2layer.py
    true_weights = {
        'W1_11': 7.0, 'W1_21': -5.0, 'b1_1': 5.0, 'b1_2': 5.0,
        'W2_11': 1.0, 'W2_12': 1.0, 'W2_21': 1.0, 'W2_22': 1.0,
        'W2_31': 3.0, 'W2_32': -3.0, 'b2_1': 0.5, 'b2_2': 0.5, 'b2_3': -2.0,
        'W3_11': 2.0, 'W3_12': 2.0, 'W3_13': 3.0, 'b3_1': 0.0
    }
    
    # Compute true function for comparison
    def true_forward(x):
        h1_1 = np.tanh(true_weights['W1_11'] * x + true_weights['b1_1'])
        h1_2 = np.tanh(true_weights['W1_21'] * x + true_weights['b1_2'])
        h2_1 = np.tanh(true_weights['W2_11'] * h1_1 + true_weights['W2_12'] * h1_2 + true_weights['b2_1'])
        h2_2 = np.tanh(true_weights['W2_21'] * h1_1 + true_weights['W2_22'] * h1_2 + true_weights['b2_2'])
        h2_3 = np.tanh(true_weights['W2_31'] * h1_1 + true_weights['W2_32'] * h1_2 + true_weights['b2_3'])
        return true_weights['W3_11'] * h2_1 + true_weights['W3_12'] * h2_2 + true_weights['W3_13'] * h2_3 + true_weights['b3_1']
    
    # Dense uniform sampling with alternating train/test split
    print("Generating train/test data with alternating split...")
    noise_std = 0.3
    x_train, y_train, x_test, y_test = generate_train_test_data(
        true_forward, n_points=100, noise_std=noise_std, seed=42
    )
    print(f"Training points: {len(x_train)}, Test points: {len(x_test)}")
    
    # Create and train the model
    print("\nTraining Neural Network...")
    print("Architecture: Input(1) -> Hidden1(2) -> Hidden2(3) -> Output(1)")
    print("=" * 50)
    
    model = BoxcarNN()
    losses = train_model(model, x_train, y_train, epochs=2000, lr=0.05)
    
    # Print learned weights
    print("\n" + "=" * 50)
    print("Learned Weights:")
    print("=" * 50)
    weights = model.get_weights()
    print("Layer 1 (input -> hidden1):")
    print(f"  W1_11 = {weights['W1_11']:.4f}, W1_21 = {weights['W1_21']:.4f}")
    print(f"  b1_1 = {weights['b1_1']:.4f}, b1_2 = {weights['b1_2']:.4f}")
    print("Layer 2 (hidden1 -> hidden2):")
    print(f"  W2_11 = {weights['W2_11']:.4f}, W2_12 = {weights['W2_12']:.4f}")
    print(f"  W2_21 = {weights['W2_21']:.4f}, W2_22 = {weights['W2_22']:.4f}")
    print(f"  W2_31 = {weights['W2_31']:.4f}, W2_32 = {weights['W2_32']:.4f}")
    print(f"  b2_1 = {weights['b2_1']:.4f}, b2_2 = {weights['b2_2']:.4f}, b2_3 = {weights['b2_3']:.4f}")
    print("Layer 3 (hidden2 -> output):")
    print(f"  W3_11 = {weights['W3_11']:.4f}, W3_12 = {weights['W3_12']:.4f}, W3_13 = {weights['W3_13']:.4f}")
    print(f"  b3_1 = {weights['b3_1']:.4f}")
    
    # Compute predictions and metrics
    x_plot = np.linspace(-6, 6, 400).reshape(-1, 1)
    with torch.no_grad():
        y_pred_plot = model(torch.FloatTensor(x_plot)).numpy()
        y_pred_train = model(torch.FloatTensor(x_train)).numpy()
        y_pred_test = model(torch.FloatTensor(x_test)).numpy()
    
    y_true_plot = true_forward(x_plot)
    
    # Calculate RMSE for train and test
    train_rmse = np.sqrt(np.mean((y_pred_train - y_train) ** 2))
    test_rmse = np.sqrt(np.mean((y_pred_test - y_test) ** 2))
    train_max_error = np.max(np.abs(y_pred_train - y_train))
    test_max_error = np.max(np.abs(y_pred_test - y_test))
    
    print(f"\nTrain RMSE: {train_rmse:.6f}, Test RMSE: {test_rmse:.6f}")
    
    # Create output directory
    import os
    output_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'case1_boxcar')
    os.makedirs(output_dir, exist_ok=True)
    
    # Plot 1: Loss vs Epoch (log scale) - separate figure
    fig1, ax1 = plt.subplots(figsize=(10, 6))
    ax1.plot(losses, 'b-', linewidth=1.5)
    ax1.set_yscale('log')
    ax1.set_xlabel('Epoch', fontsize=12)
    ax1.set_ylabel('Training Loss (MSE)', fontsize=12)
    ax1.set_title('Training Loss - Case 1 (No Overfit/Underfit)', fontsize=14, fontweight='bold')
    ax1.grid(True, linestyle='--', alpha=0.5)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'case1_boxcar_loss.png'), dpi=150)
    print(f"Loss plot saved to '{output_dir}/case1_boxcar_loss.png'")
    
    # Plot 2: Data and predictions - separate figure
    fig2, ax = plt.subplots(figsize=(12, 7))
    ax.scatter(x_train, y_train, c='skyblue', s=40, alpha=0.8, edgecolors='blue', 
               linewidth=0.5, label=f'Training Data (n={len(x_train)})', zorder=3)
    ax.scatter(x_test, y_test, c='orange', s=40, alpha=0.8, edgecolors='darkorange', 
               linewidth=0.5, label=f'Test Data (n={len(x_test)})', zorder=3)
    ax.plot(x_plot, y_pred_plot, 'r--', linewidth=2.5, label='2-Layer (2→3 neurons) Prediction', zorder=2)
    ax.plot(x_plot, y_true_plot, 'b-', linewidth=2, label='True Boxcar Function', zorder=1)
    
    # Styling
    ax.set_xlabel('Input (x)', fontsize=12)
    ax.set_ylabel('Output (y)', fontsize=12)
    ax.set_title(f'Case 1: Correct Model (2→3) | Train RMSE={train_rmse:.4f}, Test RMSE={test_rmse:.4f}', fontsize=14, fontweight='bold')
    ax.legend(loc='upper right', fontsize=10)
    ax.grid(True, linestyle='--', alpha=0.5)
    ax.axhline(y=0, color='gray', linestyle='-', linewidth=0.5)
    ax.axvline(x=0, color='gray', linestyle='--', linewidth=0.5)
    
    # Text box with weight comparison (left side)
    textstr = f'Training Data (n={len(x_train)}):\n'
    textstr += f'  RMSE: {train_rmse:.6f}\n'
    textstr += f'  Max Error: {train_max_error:.4f}\n\n'
    textstr += f'Test Data (n={len(x_test)}):\n'
    textstr += f'  RMSE: {test_rmse:.6f}\n'
    textstr += f'  Max Error: {test_max_error:.4f}\n\n'
    textstr += f'Noise: {noise_std}\n\n'
    textstr += f'Learned vs True Weights:\n'
    textstr += f'  W1_11: {weights["W1_11"]:7.3f} | {true_weights["W1_11"]:6.2f}\n'
    textstr += f'  W1_21: {weights["W1_21"]:7.3f} | {true_weights["W1_21"]:6.2f}\n'
    textstr += f'  b1_1:  {weights["b1_1"]:7.3f} | {true_weights["b1_1"]:6.2f}\n'
    textstr += f'  b1_2:  {weights["b1_2"]:7.3f} | {true_weights["b1_2"]:6.2f}\n'
    textstr += f'  W2_11: {weights["W2_11"]:7.3f} | {true_weights["W2_11"]:6.2f}\n'
    textstr += f'  W2_21: {weights["W2_21"]:7.3f} | {true_weights["W2_21"]:6.2f}\n'
    textstr += f'  W2_31: {weights["W2_31"]:7.3f} | {true_weights["W2_31"]:6.2f}\n'
    textstr += f'  W3_11: {weights["W3_11"]:7.3f} | {true_weights["W3_11"]:6.2f}\n'
    textstr += f'  W3_12: {weights["W3_12"]:7.3f} | {true_weights["W3_12"]:6.2f}\n'
    textstr += f'  W3_13: {weights["W3_13"]:7.3f} | {true_weights["W3_13"]:6.2f}\n'
    textstr += f'  b3_1:  {weights["b3_1"]:7.3f} | {true_weights["b3_1"]:6.2f}'
    
    props = dict(boxstyle='round', facecolor='wheat', alpha=0.8)
    ax.text(0.02, 0.98, textstr, transform=ax.transAxes, fontsize=9,
            verticalalignment='top', fontfamily='monospace', bbox=props)
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'case1_boxcar_results.png'), dpi=150)
    plt.show()
    print(f"Data plot saved to '{output_dir}/case1_boxcar_results.png'")
