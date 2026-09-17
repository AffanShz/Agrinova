import 'package:flutter_test/flutter_test.dart';
import 'package:agrinova/features/scanner/bloc/scanner_bloc.dart';
import 'package:agrinova/features/scanner/bloc/scanner_event.dart';
import 'package:agrinova/features/scanner/bloc/scanner_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScannerBloc Tests', () {
    late ScannerBloc scannerBloc;

    setUp(() {
      scannerBloc = ScannerBloc();
    });

    tearDown(() {
      scannerBloc.close();
    });

    test('Initial state is ScannerInitial with default plant Tomat', () {
      expect(scannerBloc.state, const ScannerInitial(selectedPlantType: 'Tomat'));
    });

    test('SetPlantType updates selected plant type when supported', () async {
      final states = <ScannerState>[];
      final subscription = scannerBloc.stream.listen(states.add);

      scannerBloc.add(SetPlantType('Padi'));
      await pumpEventQueue();

      expect(states.length, 1);
      expect(states.first, const ScannerInitial(selectedPlantType: 'Padi'));

      await subscription.cancel();
    });

    test('SetPlantType ignores unsupported plant type', () async {
      final states = <ScannerState>[];
      final subscription = scannerBloc.stream.listen(states.add);

      scannerBloc.add(SetPlantType('Mangga'));
      await pumpEventQueue();

      expect(states.isEmpty, true);

      await subscription.cancel();
    });

    test('ResetScanner resets state to ScannerInitial', () async {
      final states = <ScannerState>[];
      final subscription = scannerBloc.stream.listen(states.add);

      scannerBloc.add(SetPlantType('Teh'));
      scannerBloc.add(ResetScanner());
      await pumpEventQueue();

      expect(states.last, const ScannerInitial(selectedPlantType: 'Teh'));

      await subscription.cancel();
    });
  });
}
