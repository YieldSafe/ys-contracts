# Contributing to YieldSafe Contracts

Thank you for your interest in contributing to YieldSafe smart contracts! This guide will help you get started.

## Contribution Workflow

1. **Fork the Repository**: Click the "Fork" button on GitHub to create your personal copy
2. **Clone Your Fork**:

```bash
git clone https://github.com/YOUR_USERNAME/ys-contracts.git
cd ys-contracts
```

3. **Create a Feature Branch:**

```bash
git checkout -b feature/your-feature-name
```

4. **Make Your Changes:** Implement your contract changes or improvements

5. **Test Your Changes:**

```bash
forge build
forge test
```

6. **Commit Your Changes:**

```bash
git commit -m "Add your meaningful commit message"
```

7. **Push to Your Fork:**

```bash
git push origin feature/your-feature-name
```

8. **Create a Pull Request:** Go to the main repository and create a PR from your fork to the main branch

## Development Setup

### Prerequisites

- Foundry (includes Forge)
- Solidity knowledge

### Getting Started

```bash
forge build
forge test
```

## Code Standards

- All contracts should be well-documented with NatSpec comments
- Write comprehensive tests for all contract functionality
- Ensure all tests pass:

```bash
forge test
```

- Follow Solidity best practices and security guidelines
- Gas optimization is encouraged but not at the cost of clarity

## Testing Requirements

- All new features must include tests
- Tests should cover both happy paths and edge cases
- Maintain or improve test coverage

## Security Considerations

Smart contracts handle real value. Security is critical.

- Follow established Solidity security patterns
- Be aware of common vulnerabilities (reentrancy, overflow, etc.)

## Pull Request Guidelines

- Keep PRs focused and reasonably sized
- Write clear PR descriptions explaining the changes and rationale
- Reference any related issues
- Ensure all tests pass
- Highlight any security considerations in the PR description
- Be responsive to review feedback

## Code of Conduct

Please be respectful and constructive in all interactions with other contributors.

## Questions?

Feel free to open an issue to ask questions or start a discussion!
