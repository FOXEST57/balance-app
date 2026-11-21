import 'package:balance/features/weighing/domain/entities/user_profile.dart';
import 'package:balance/features/weighing/domain/entities/scale_frame.dart';
import 'package:balance/features/weighing/domain/services/ac27_parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _frame({
  required int type,
  int flags = 0,
  int weightRawUnits = 0,
  int resultRawImpedance = 0,
}) {
  final List<int> bytes = List<int>.filled(Ac27Parser.frameLength, 0);
  bytes[0] = 0xac;
  bytes[1] = 0x27;
  bytes[2] = flags;
  bytes[3] = (weightRawUnits >> 16) & 0xff;
  bytes[4] = (weightRawUnits >> 8) & 0xff;
  bytes[5] = weightRawUnits & 0xff;
  if (type == Ac27Parser.typeResult) {
    bytes[4] = (resultRawImpedance >> 8) & 0xff;
    bytes[5] = resultRawImpedance & 0xff;
  }
  bytes[18] = type;
  var sum = 0;
  for (var i = 2; i <= 18; i++) {
    sum += bytes[i];
  }
  bytes[19] = sum & 0xff;
  return bytes;
}

void main() {
  group('Ac27Parser', () {
    test(
      'ignores a D0 foot-balance frame instead of treating it as total weight',
      () {
        final parser = Ac27Parser();
        final List<int> balanceFrame = _frame(type: Ac27Parser.typeBalance)
          ..[3] = 0x23
          ..[4] = 0xfa
          ..[5] = 0x02
          ..[6] = 0x3a;
        var sum = 0;
        for (var i = 2; i <= 18; i++) {
          sum += balanceFrame[i];
        }
        balanceFrame[19] = sum & 0x1f;

        expect(parser.isValidFrame(balanceFrame), isTrue);
        expect(balanceFrame[19], 0x09);
        expect(parser.parse(balanceFrame), isNull);
      },
    );

    test('recognizes the captured empty-scale D5 frame as zero weight', () {
      final List<int> emptyFrame = List<int>.filled(Ac27Parser.frameLength, 0)
        ..[0] = 0xac
        ..[1] = 0x27
        ..[2] = 0x06
        ..[3] = 0x8c
        ..[17] = 0x07
        ..[18] = Ac27Parser.typeWeight
        ..[19] = 0x0e;
      final parser = Ac27Parser();

      expect(parser.isValidFrame(emptyFrame), isTrue);
      final ScaleFrame? frame = parser.parse(emptyFrame);

      expect(frame, isNotNull);
      expect(frame!.weightKg, 0);
      expect(frame.stabilized, isFalse);
      expect(frame.isUnloaded, isTrue);
      expect(frame.isFinal, isFalse);
    });

    test('an unloaded frame clears the previous locked weight', () {
      final parser = Ac27Parser()
        ..parse(
          _frame(
            type: Ac27Parser.typeWeight,
            flags: Ac27Parser.lockedMask,
            weightRawUnits: 25740,
          ),
        );

      parser.parse(_frame(type: Ac27Parser.typeWeight));
      final ScaleFrame? result = parser.parse(
        _frame(type: Ac27Parser.typeResult, flags: 1, resultRawImpedance: 512),
      );

      expect(result, isNull);
    });

    test('converts the real captured locked frame to 25.74 kg', () {
      // Trame réellement capturée sur la balance : AC 27 86 8C 64 8C ... D5
      final List<int> captured = <int>[
        0xac, 0x27, 0x86, 0x8c, 0x64, 0x8c, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0xd5, 0x1e,
      ];
      final parser = Ac27Parser();

      expect(parser.isValidFrame(captured), isTrue);
      final frame = parser.parse(captured);

      expect(frame, isNotNull);
      expect(frame!.weightKg, 25.74);
      expect(frame.stabilized, isTrue);
      expect(frame.impedanceOhm, isNull);
    });

    test('converts the raw value 25740 to 25.74 kg', () {
      final parser = Ac27Parser();
      final frame = parser.parse(
        _frame(
          type: Ac27Parser.typeWeight,
          flags: Ac27Parser.lockedMask,
          weightRawUnits: 25740,
        ),
      );

      expect(frame, isNotNull);
      expect(frame!.weightKg, 25.74);
      expect(frame.stabilized, isTrue);
      expect(frame.impedanceOhm, isNull);
    });

    test('detects stability after an unchanged weight plateau', () {
      final parser = Ac27Parser();
      final DateTime start = DateTime(2026);
      ScaleFrame? frame;
      for (var i = 0; i < Ac27Parser.plateauFrames; i++) {
        frame = parser.parse(
          _frame(type: Ac27Parser.typeWeight, weightRawUnits: 25740),
          receivedAt: start.add(Duration(milliseconds: i * 250)),
        );
      }

      expect(frame, isNotNull);
      expect(frame!.weightKg, 25.74);
      expect(frame.stabilized, isTrue);
    });

    test('rejects a frame with an invalid checksum', () {
      final bytes = _frame(
        type: Ac27Parser.typeWeight,
        flags: Ac27Parser.lockedMask,
        weightRawUnits: 25740,
      );
      bytes[19] = (bytes[19] + 1) & 0xff;

      expect(Ac27Parser().parse(bytes), isNull);
    });

    test(
      'builds the Fitdays profile handshake with the configured profile',
      () {
        const profile = UserProfile(
          sex: Sex.female,
          age: 42,
          heightCm: 168,
          activityLevel: ActivityLevel.moderate,
          targetWeightKg: 65,
        );
        final parser = Ac27Parser();
        final frames = parser.buildHandshake(
          profile,
          now: DateTime.fromMillisecondsSinceEpoch(0),
        );

        expect(frames, hasLength(3));
        expect(frames.every(parser.isValidFrame), isTrue);
        expect(frames.first[9], 168);
        expect(frames.first[12], 42);
        expect(frames.first[13], 2);
        expect(frames[1][2], 1);
        expect(frames[1][18], 0xdf);
        expect(frames[2], frames.first);
      },
    );

    test('pairs a D6 impedance result with the last locked weight', () {
      final parser = Ac27Parser()
        ..parse(
          _frame(
            type: Ac27Parser.typeWeight,
            flags: Ac27Parser.lockedMask,
            weightRawUnits: 25740,
          ),
        );
      final result = parser.parse(
        _frame(type: Ac27Parser.typeResult, flags: 1, resultRawImpedance: 512),
      );

      expect(result, isNotNull);
      expect(result!.weightKg, 25.74);
      expect(result.impedanceOhm, 512);
      expect(result.isFinal, isTrue);
    });
  });
}
