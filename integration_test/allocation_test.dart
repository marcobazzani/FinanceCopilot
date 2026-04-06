import 'package:finance_copilot/database/tables.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('defaultAssetClassFor maps instrument types correctly',
      (tester) async {
    await pumpApp(tester);

    expect(defaultAssetClassFor(InstrumentType.bond), AssetClass.fixedIncome);
    expect(defaultAssetClassFor(InstrumentType.etc), AssetClass.commodities);
    expect(defaultAssetClassFor(InstrumentType.crypto), AssetClass.crypto);
    expect(defaultAssetClassFor(InstrumentType.fund), AssetClass.multiAsset);
    expect(defaultAssetClassFor(InstrumentType.etf), AssetClass.equity);
    expect(defaultAssetClassFor(InstrumentType.stock), AssetClass.equity);
  });
}
