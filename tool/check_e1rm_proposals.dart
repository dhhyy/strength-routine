import 'dart:io';

import 'package:strength_routine/data/local_training_store.dart';
import 'package:strength_routine/domain/e1rm.dart';
import 'package:strength_routine/domain/e1rm_proposals.dart';

Future<void> main() async {
  final file = File(
    '/Users/yudongheon/Library/Developer/CoreSimulator/Devices/'
    'E0F071B5-1CF2-4010-9C76-E0A9F0AFFA4F/data/Containers/Data/Application/'
    'D16F2BC1-2209-4CCD-9530-2A57462CDC3C/Library/Application Support/'
    'training-state.json',
  );
  final state = await LocalTrainingStore(file).load();
  stdout.writeln('flag=$e1rmFeatureFlag');
  stdout.writeln('plan=${state.activePlan?.program.title}');
  stdout.writeln('actuals=${state.setActuals.length}');
  final asOf = DateTime.now();
  stdout.writeln('asOf local=$asOf');
  final proposals = buildE1rmProposals(
    state,
    planId: state.activePlan!.id,
    asOf: asOf,
  );
  stdout.writeln('proposals=${proposals.length}');
  for (final p in proposals) {
    stdout.writeln(
      '  ${p.lift.key} ${p.sourceWeightKg}x${p.sourceRepetitions} '
      '-> ${p.estimatedKg} ${p.exerciseName} date=${p.plannedDate}',
    );
  }
}
