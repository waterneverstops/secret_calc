import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  bool _secretUnlocked = false;
  late AnimationController _secretController;
  late AnimationController _breathController;
  late Animation<double> _secretOpacity;
  late Animation<double> _breathAnimation;

  // 9 lives
  static const _secretNumber = 9.0;

  @override
  void initState() {
    super.initState();
    _secretController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 3200),
      vsync: this,
    )..repeat(reverse: true);

    _secretOpacity = CurvedAnimation(
      parent: _secretController,
      curve: Curves.easeInOut,
    );
    _breathAnimation = CurvedAnimation(
      parent: _breathController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _secretController.dispose();
    _breathController.dispose();
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

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    if (_secretUnlocked) {
      _dismissSecret();
      return KeyEventResult.handled;
    }

    final digitKeys = {
      LogicalKeyboardKey.digit0: '0', LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.digit2: '2', LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.digit4: '4', LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.digit6: '6', LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.digit8: '8', LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad0: '0', LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.numpad2: '2', LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.numpad4: '4', LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.numpad6: '6', LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.numpad8: '8', LogicalKeyboardKey.numpad9: '9',
    };

    if (digitKeys.containsKey(key)) {
      setState(() => _inputDigit(digitKeys[key]!));
      return KeyEventResult.handled;
    }

    final opKeys = {
      LogicalKeyboardKey.add:          '+',
      LogicalKeyboardKey.numpadAdd:    '+',
      LogicalKeyboardKey.minus:        '−',
      LogicalKeyboardKey.numpadSubtract: '−',
      LogicalKeyboardKey.asterisk:     '×',
      LogicalKeyboardKey.numpadMultiply: '×',
      LogicalKeyboardKey.slash:        '÷',
      LogicalKeyboardKey.numpadDivide: '÷',
    };

    if (opKeys.containsKey(key)) {
      setState(() => _setOperator(opKeys[key]!));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadEqual ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      setState(_calculate);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace) {
      setState(_backspace);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.delete) {
      setState(_clear);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.comma) {
      setState(() => _inputDigit('.'));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.percent) {
      setState(_percent);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ── palette ──────────────────────────────────────────────────────────────────

  static const _bg = Color(0xFF0F0F1A);
  static const _displayBg = Color(0xFF16162A);
  static const _btnDark = Color(0xFF1E1E32);
  static const _btnMid = Color(0xFF2A2A45);
  static const _btnAccent = Color(0xFF6C63FF);
  static const _btnOp = Color(0xFF3D3A6B);

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF07070F),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 720),
            child: SafeArea(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 48,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _buildDisplay(),
                        const SizedBox(height: 8),
                        Expanded(child: _buildButtons()),
                        _buildFooter(),
                      ],
                    ),
                  ),
                  if (_secretUnlocked) _buildSecretOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisplay() {
    final showEars = _display == '0' && _expression.isEmpty && !_justCalculated;

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
          Stack(
            alignment: Alignment.centerRight,
            clipBehavior: Clip.none,
            children: [
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
              if (showEars) _CatEars(breathAnimation: _breathAnimation),
            ],
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
        animation: _breathAnimation,
        builder: (_, __) {
          final opacity = 0.18 + _breathAnimation.value * 0.18;
          return Text(
            'v1.0  ·  lives: ?',
            style: TextStyle(
              color: Colors.white.withOpacity(opacity),
              fontSize: 11,
              letterSpacing: 1.5,
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
          decoration: BoxDecoration(
            color: const Color(0xF0120C0A),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: _CatSecretContent(breathAnimation: _breathAnimation),
        ),
      ),
    );
  }
}

// ── Cat ears drawn on top of the zero ────────────────────────────────────────

class _CatEars extends StatelessWidget {
  const _CatEars({required this.breathAnimation});
  final Animation<double> breathAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breathAnimation,
      builder: (_, __) {
        final opacity = 0.04 + breathAnimation.value * 0.04;
        return Positioned(
          right: 18,
          top: -18,
          child: Opacity(
            opacity: opacity,
            child: CustomPaint(
              size: const Size(48, 20),
              painter: _EarsPainter(),
            ),
          ),
        );
      },
    );
  }
}

class _EarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // left ear triangle
    final leftEar = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.22, 0)
      ..lineTo(size.width * 0.44, size.height)
      ..close();

    // right ear triangle
    final rightEar = Path()
      ..moveTo(size.width * 0.56, size.height)
      ..lineTo(size.width * 0.78, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(leftEar, paint);
    canvas.drawPath(rightEar, paint);
  }

  @override
  bool shouldRepaint(_EarsPainter oldDelegate) => false;
}

// ── Secret overlay ────────────────────────────────────────────────────────────

class _CatSecretContent extends StatelessWidget {
  const _CatSecretContent({required this.breathAnimation});
  final Animation<double> breathAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breathAnimation,
      builder: (_, __) {
        final t = breathAnimation.value;
        final warmColor = Color.lerp(
          const Color(0xFFD4956A),
          const Color(0xFFE8C49A),
          t,
        )!;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // cat face
            Text(
              '=^ . ^=',
              style: TextStyle(
                fontSize: 52,
                color: warmColor,
                letterSpacing: 4,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'meow',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w200,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 12,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 240,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: warmColor.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'cats have nine lives.\nyou found the one hidden here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                  height: 1.7,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'tap to close',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Button ─────────────────────────────────────────────────────────────────────

class _CalcButton extends StatefulWidget {
  const _CalcButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed ? widget.color.withOpacity(0.65) : widget.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: widget.color.withOpacity(0.22),
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
  }
}
