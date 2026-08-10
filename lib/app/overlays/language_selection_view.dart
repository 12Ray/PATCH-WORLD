import 'package:flutter/material.dart';
import 'package:patch_world/services/localization_service.dart';

typedef LanguageSelectionCallback = Future<void> Function(String languageCode);

final class LanguageSelectionView extends StatefulWidget {
  const LanguageSelectionView({required this.onSelected, super.key});

  final LanguageSelectionCallback onSelected;

  @override
  State<LanguageSelectionView> createState() => _LanguageSelectionViewState();
}

final class _LanguageSelectionViewState extends State<LanguageSelectionView> {
  String? _loadingCode;
  bool _failed = false;

  Future<void> _select(String code) async {
    if (_loadingCode != null) return;
    setState(() {
      _loadingCode = code;
      _failed = false;
    });
    try {
      await widget.onSelected(code);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCode = null;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/images/ui/patch_world_key_art.png'),
        fit: BoxFit.cover,
        opacity: 0.28,
      ),
    ),
    child: ColoredBox(
      color: const Color(0xD9080B14),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: const Color(0xEE111827),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'PATCH//WORLD',
                      style: TextStyle(
                        color: Color(0xFF36E1FF),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'LANGUAGE  /  언어  /  言語',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFF4FD8),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select your language\n사용할 언어를 선택하세요\n言語を選択してください',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFA9B4C8), height: 1.45),
                    ),
                    const SizedBox(height: 24),
                    for (final language
                        in LocalizationService.supportedLanguages) ...<Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loadingCode == null
                              ? () => _select(language.code)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _loadingCode == language.code
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(language.nativeName),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                    if (_failed)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Could not save the language. Please try again.\n'
                          '언어를 저장하지 못했습니다. 다시 시도하세요.\n'
                          '言語を保存できませんでした。もう一度お試しください。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFFF6464),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
