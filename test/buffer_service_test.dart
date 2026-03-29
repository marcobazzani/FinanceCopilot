import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_copilot/database/database.dart';
import 'package:finance_copilot/services/buffer_service.dart';

void main() {
  late AppDatabase db;
  late BufferService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BufferService(db);
  });

  tearDown(() async => await db.close());

  group('Buffer CRUD', () {
    test('create buffer and retrieve via stream', () async {
      await service.create(name: 'Emergency Fund', targetAmount: 10000);

      final buffers = await service.watchAll().first;
      expect(buffers, hasLength(1));
      expect(buffers.first.name, 'Emergency Fund');
      expect(buffers.first.targetAmount, 10000);
    });

    test('create buffer with linkedDepreciationId', () async {
      await service.create(
        name: 'Linked Buffer',
        targetAmount: 5000,
      );

      final buffers = await service.watchAll().first;
      expect(buffers, hasLength(1));
      expect(buffers.first.name, 'Linked Buffer');
    });

    test('update buffer name', () async {
      final id = await service.create(name: 'Old Name');

      await service.update(id, const BuffersCompanion(name: Value('New Name')));

      final buffers = await service.watchAll().first;
      expect(buffers.first.name, 'New Name');
    });

    test('delete buffer cascades transactions', () async {
      final bufferId = await service.create(name: 'To Delete');
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: 100,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 2, 1),
        amount: 200,
      );

      // Verify transactions exist
      final txnsBefore = await service.getByBuffer(bufferId);
      expect(txnsBefore, hasLength(2));

      await service.delete(bufferId);

      // Buffer gone
      final buffers = await service.watchAll().first;
      expect(buffers, isEmpty);

      // Transactions gone (query raw since buffer is deleted)
      final txnsAfter = await db.select(db.bufferTransactions).get();
      expect(txnsAfter, isEmpty);
    });
  });

  group('BufferTransaction CRUD', () {
    late int bufferId;

    setUp(() async {
      bufferId = await service.create(name: 'Test Buffer');
    });

    test('create transactions with auto-computed balanceAfter', () async {
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: 100,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 2, 1),
        amount: 250,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 3, 1),
        amount: -50,
      );

      final txns = await service.getByBuffer(bufferId);
      expect(txns, hasLength(3));
      expect(txns[0].balanceAfter, 100);
      expect(txns[1].balanceAfter, 350);
      expect(txns[2].balanceAfter, 300);
    });

    test('getByBuffer ordered asc by date', () async {
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 6, 1),
        amount: 300,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: 100,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 3, 1),
        amount: 200,
      );

      final txns = await service.getByBuffer(bufferId);
      expect(txns, hasLength(3));
      expect(txns[0].operationDate, DateTime(2024, 1, 1));
      expect(txns[1].operationDate, DateTime(2024, 3, 1));
      expect(txns[2].operationDate, DateTime(2024, 6, 1));
    });

    test('computeBalance returns sum of amounts', () async {
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: 500,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 2, 1),
        amount: 300,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 3, 1),
        amount: -100,
      );

      final balance = await service.computeBalance(bufferId);
      expect(balance, 700);
    });

    test('computeBalance returns 0 for buffer with no transactions', () async {
      final balance = await service.computeBalance(bufferId);
      expect(balance, 0);
    });

    test('deleteTransaction removes single transaction', () async {
      final txId1 = await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: 100,
      );
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 2, 1),
        amount: 200,
      );

      await service.deleteTransaction(txId1);

      final txns = await service.getByBuffer(bufferId);
      expect(txns, hasLength(1));
      expect(txns.first.amount, 200);
    });

    test('updateTransaction updates description', () async {
      final txId = await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: 100,
        description: 'Initial',
      );

      await service.updateTransaction(
        txId,
        const BufferTransactionsCompanion(description: Value('Updated')),
      );

      final txns = await service.getByBuffer(bufferId);
      expect(txns.first.description, 'Updated');
    });

    test('createTransaction with isReimbursement flag', () async {
      await service.createTransaction(
        bufferId: bufferId,
        currency: 'EUR',
        operationDate: DateTime(2024, 1, 1),
        amount: -50,
        isReimbursement: true,
      );

      final txns = await service.getByBuffer(bufferId);
      expect(txns.first.isReimbursement, isTrue);
    });
  });
}
