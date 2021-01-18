import 'dart:math';

import 'package:four_in_a_row/play/models/common/field.dart';
import 'package:four_in_a_row/play/models/common/player.dart';

enum CpuDifficulty { EASY, MEDIUM, HARD }

abstract class Cpu {
  final Player cpu = Player.Two;
  final Random _random = Random(DateTime.now().millisecond);

  static Cpu fromDifficulty(CpuDifficulty difficulty) {
    switch (difficulty) {
      case CpuDifficulty.EASY:
        return EasyCpu();
      case CpuDifficulty.MEDIUM:
        return MediumCpu();
      case CpuDifficulty.HARD:
        return HardCpu();
    }
  }

  Future<int> chooseCol(Field field);
}

class EasyCpu extends Cpu {
  @override
  Future<int> chooseCol(Field field) async {
    await Future.delayed(Duration(seconds: 1 + _random.nextInt(2)));
    int col = 0;
    bool foundColumn = true;
    int tries = 0;
    do {
      col = _random.nextInt(Field.size);
      foundColumn = true;
      final fieldCopy = FieldPlaying.from(field.clone());
      fieldCopy.dropChipNamed(col, cpu, vibrate: false);
      var winDetails = fieldCopy.checkWin();
      if (winDetails != null &&
          winDetails is WinDetailsWinner &&
          winDetails.winner == cpu.other) {
        foundColumn = false;
      }
      tries += 1;
    } while (foundColumn && tries < Field.size);

    return col;
  }

  @override
  String toString() => 'DUMB CPU';
}

class MediumCpu extends Cpu {
  @override
  Future<int> chooseCol(Field field) async {
    final List<double> scores = List.filled(Field.size, 0);

    await Future.delayed(Duration(seconds: 2 + _random.nextInt(2)));
    return _compute(field, 0, 1, scores);
  }

  int _compute(Field field, int step, int deepness, List<double?> scores) {
    for (var i = 0; i < Field.size; ++i) {
      final fieldCopy = FieldPlaying.from(field.clone());

      final target = fieldCopy.array[i].lastIndexOf(null);
      if (target == -1) {
        scores[i] = null;
        continue;
      }

      fieldCopy.dropChipNamed(i, cpu, vibrate: false);
      if (fieldCopy.checkWin() != null) {
        var score = scores[i];
        scores[i] = (score ?? 0) + deepness / (step + 1);
        continue;
      }

      for (var j = 0; j < Field.size; ++j) {
        final target = fieldCopy.array[i].lastIndexOf(null);
        if (target == -1) {
          continue;
        }

        fieldCopy.dropChipNamed(j, cpu, vibrate: false);
        if (fieldCopy.checkWin() != null) {
          var score = scores[i];
          scores[i] = (score ?? 0) - deepness / (step + 1);
          continue;
        }

        if (step + 1 < deepness) {
          _compute(field, step + 1, deepness, scores);
        }
      }
    }

    return _getBestScoreIndex(scores);
  }

  int _getBestScoreIndex(List<double?> scores) {
    int bestScoreIndex = scores.indexWhere((s) => s != null);
    scores.asMap().forEach((index, score) {
      if (score != null &&
          (score > scores[bestScoreIndex]! ||
              (score == scores[bestScoreIndex] && _random.nextBool()))) {
        bestScoreIndex = index;
      }
    });
    return bestScoreIndex;
  }

  @override
  String toString() => 'MEDIUM CPU';
}

class HardCpu extends MediumCpu {
  @override
  Future<int> chooseCol(Field field) async {
    final List<double> scores = List.filled(Field.size, 0);

    await Future.delayed(Duration(seconds: 3 + _random.nextInt(2)));
    return _compute(field, 0, 4, scores);
  }

  @override
  String toString() => 'HARD CPU';
}
