import 'dart:math';
import 'package:flutter/material.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with TickerProviderStateMixin {
  String _display = '0';
  String _expression = '';
  double? _firstOperand;
  String? _operator;
  bool _waitingForOperand = false;
  bool _justCalculated = false;

  // Secret tracking — checks if result was 1337
  bool _secretUnlocked = false;
  late AnimationController _secretController;
  late AnimationController _glowController;
  late Animation<double> _secretOpacity;
  late Animation<double> _glowAnimation;

  static const _secretNumber = 1337.0;

  @override
  void initState() {
    super.initState();
    _secretController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _secretOpacity = CurvedAnimation(
      parent: _secretController,
      curve: Curves.easeIn,
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _secretController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _onButton(String label) {
    if (_secretUnlocked) {
      _dismissSecret();
      return;
    }

    setState(() {
      if (label == 'C') {
        _clear();
      } else if (label == '⌫') {
        _backspace();
      } else if (['+', '−', '×', '÷'].contains(label)) {
        _setOperator(label);
      } else if (label == '=') {
        _calculate();
      } else if (label == '+/−') {
        _toggleSign();
      } else if (label == '%') {
        _percent();
      } else {
        _inputDigit(label);
      }
    });
  }

  void _clear() {
    _display = '0';
    _expression = '';
    _firstOperand = null;
    _operator = null;
    _waitingForOperand = false;
    _justCalculated = false;
  }

  void _backspace() {
    if (_justCalculated) return;
    if (_display.length <= 1) {
      _display = '0';
    } else {
      _display = _display.substring(0, _display.length - 1);
    }
  }

  void _inputDigit(String digit) {
    if (_justCalculated) {
      _display = digit == '.' ? '0.' : digit;
      _justCalculated = false;
      return;
    }
    if (_waitingForOperand) {
      _display = digit == '.' ? '0.' : digit;
      _waitingForOperand = false;
      return;
    }
    if (digit == '.' && _display.contains('.')) return;
    if (_display == '0' && digit != '.') {
      _display = digit;
    } else {
      if (_display.length < 12) _display += digit;
    }
  }

  void _setOperator(String op) {
    final val = double.tryParse(_display);
    if (val == null) return;

    if (_firstOperand != null && !_waitingForOperand) {
      _performCalc();
    }

    _firstOperand = double.tryParse(_display);
    _operator = op;
    _expression = '${_formatResult(_firstOperand!)} $op';
    _waitingForOperand = true;
    _justCalculated = false;
  }

  void _calculate() {
    if (_operator == null || _firstOperand == null) return;
    _performCalc();
    _operator = null;
    _firstOperand = null;
    _justCalculated = true;
  }

  void _performCalc() {
    final a = _firstOperand!;
    final b = double.tryParse(_display) ?? 0;
    double result;

    switch (_operator) {
      case '+':
        result = a + b;
      case '−':
        result = a - b;
      case '×':
        result = a * b;
      case '÷':
        result = b == 0 ? double.nan : a / b;
      default:
        return;
    }

    _expression = '';
    if (result.isNaN) {
      _display = 'Error';
    } else {
      _display = _formatResult(result);
      if (result == _secretNumber) {
        _triggerSecret();
      }
    }
  }

  String _formatResult(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e12) {
      return v.toInt().toString();
    }
    final s = v.toStringAsExponential(6);
    final compact = double.parse(v.toStringAsFixed(8)).toString();
    return compact.length < s.length ? compact : s;
  }

  void _toggleSign() {
    final val = double.tryParse(_display);
    if (val == null) return;
    _display = _formatResult(-val);
  }

  void _percent() {
    final val = double.tryParse(_display);
    if (val == null) return;
    _display = _formatResult(val / 100);
  }

  void _triggerSecret() {
    _secretUnlocked = true;
    _secretController.forward();
  }

  void _dismissSecret() {
    _secretController.reverse().then((_) {
      setState(() => _secretUnlocked = false);
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  static const _bg = Color(0xFF0F0F1A);
  static const _displayBg = Color(0xFF16162A);
  static const _btnDark = Color(0xFF1E1E32);
  static const _btnMid = Color(0xFF2A2A45);
  static const _btnAccent = Color(0xFF6C63FF);
  static const _btnOp = Color(0xFF3D3A6B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildDisplay(),
                const SizedBox(height: 8),
                Expanded(child: _buildButtons()),
                _buildFooter(),
              ],
            ),
            if (_secretUnlocked) _buildSecretOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      color: _displayBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_expression.isNotEmpty)
            Text(
              _expression,
              style: const TextStyle(
                color: Color(0xFF888899),
                fontSize: 18,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            )
          else
            const SizedBox(height: 22),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              _display,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w300,
                letterSpacing: -2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    const rows = [
      ['C', '⌫', '%', '÷'],
      ['7', '8', '9', '×'],
      ['4', '5', '6', '−'],
      ['1', '2', '3', '+'],
      ['+/−', '0', '.', '='],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: rows.map((row) {
          return Expanded(
            child: Row(
              children: row.map((label) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _CalcButton(
                      label: label,
                      color: _buttonColor(label),
                      textColor: _buttonTextColor(label),
                      onTap: () => _onButton(label),
                      glowAnimation: label == '=' ? _glowAnimation : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _buttonColor(String label) {
    if (label == '=') return _btnAccent;
    if (['+', '−', '×', '÷'].contains(label)) return _btnOp;
    if (['C', '⌫', '%', '+/−'].contains(label)) return _btnMid;
    return _btnDark;
  }

  Color _buttonTextColor(String label) {
    if (label == '=') return Colors.white;
    if (['+', '−', '×', '÷'].contains(label)) return const Color(0xFFB0AAFF);
    if (['C', '⌫', '%', '+/−'].contains(label)) {
      return const Color(0xFFCCCCDD);
    }
    return Colors.white;
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (_, __) {
          final opacity = 0.25 + _glowAnimation.value * 0.35;
          return Text(
            'v1.3.3.7  ·  not all numbers are equal',
            style: TextStyle(
              color: Colors.white.withOpacity(opacity),
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecretOverlay() {
    return FadeTransition(
      opacity: _secretOpacity,
      child: GestureDetector(
        onTap: _dismissSecret,
        child: Container(
          color: Colors.black.withOpacity(0.92),
          alignment: Alignment.center,
          child: _SecretContent(glowAnimation: _glowAnimation),
        ),
      ),
    );
  }
}

// ── Secret overlay content ───────────────────────────────────────────────────

class _SecretContent extends StatelessWidget {
  const _SecretContent({required this.glowAnimation});
  final Animation<double> glowAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (_, __) {
        final glow = glowAnimation.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  const Color(0xFF6C63FF),
                  Color.lerp(
                    const Color(0xFFFF63C3),
                    const Color(0xFF63FFEE),
                    glow,
                  )!,
                ],
              ).createShader(bounds),
              child: const Text(
                '1337',
                style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Y0U F0UND 1T',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.95),
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFF6C63FF),
                    const Color(0xFFFF63C3),
                    glow,
                  )!.withOpacity(0.6),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '"1337" — leet speak.\nThe language of those who look deeper.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFBBBBCC),
                  fontSize: 14,
                  height: 1.6,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'tap anywhere to continue',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Button widget ────────────────────────────────────────────────────────────

class _CalcButton extends StatefulWidget {
  const _CalcButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.glowAnimation,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final Animation<double>? glowAnimation;

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isEquals = widget.label == '=';

    Widget btn = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed
              ? widget.color.withOpacity(0.7)
              : widget.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.color.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: TextStyle(
            color: widget.textColor,
            fontSize: widget.label.length > 1 ? 18 : 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    if (isEquals && widget.glowAnimation != null) {
      return AnimatedBuilder(
        animation: widget.glowAnimation!,
        builder: (_, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF)
                      .withOpacity(0.15 + widget.glowAnimation!.value * 0.25),
                  blurRadius: 16 + widget.glowAnimation!.value * 10,
                  spreadRadius: widget.glowAnimation!.value * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: btn,
      );
    }

    return btn;
  }
}
