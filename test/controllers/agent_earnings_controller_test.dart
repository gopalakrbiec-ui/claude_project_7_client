import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:life_event_editor/controllers/agent_earnings_controller.dart';
import 'package:life_event_editor/models/agent_earnings.dart';
import 'package:life_event_editor/repositories/agent_repository.dart';
import 'package:life_event_editor/api/api_error.dart';

class MockAgentRepository extends Mock implements AgentRepository {}

AgentEarnings _fakeEarnings({int total = 5000, List<CommissionEntry>? entries}) {
  return AgentEarnings(
    totalCommissionPaise: total,
    totalCommissionDisplay: '₹${total ~/ 100}',
    entries: entries ?? [],
  );
}

CommissionEntry _fakeEntry({String id = 'e1', int amount = 2500}) {
  return CommissionEntry(
    id: id,
    orderId: 'order-$id',
    amountPaise: amount,
    amountDisplay: '₹${amount ~/ 100}',
    customerName: 'Test Customer',
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  late MockAgentRepository mockRepo;

  setUp(() {
    mockRepo = MockAgentRepository();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  }

  group('AgentEarningsController', () {
    test('build() loads earnings successfully', () async {
      final earnings = _fakeEarnings(total: 10000, entries: [_fakeEntry()]);
      when(() => mockRepo.getEarnings()).thenAnswer((_) async => earnings);

      final container = makeContainer();
      addTearDown(container.dispose);

      // Wait for async build to complete
      final result = await container.read(agentEarningsControllerProvider.future);

      expect(result.totalCommissionPaise, 10000);
      expect(result.totalCommissionDisplay, '₹100');
      expect(result.entries.length, 1);
      expect(result.entries.first.customerName, 'Test Customer');
    });

    test('build() propagates NetworkError as AsyncError', () async {
      when(() => mockRepo.getEarnings())
          .thenThrow(const NetworkError(message: 'offline'));

      final container = makeContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(agentEarningsControllerProvider.future),
        throwsA(isA<NetworkError>()),
      );
    });

    test('build() propagates ServerError as AsyncError', () async {
      when(() => mockRepo.getEarnings()).thenThrow(
        const ServerError(statusCode: 500, message: 'Internal server error'),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await expectLater(
        container.read(agentEarningsControllerProvider.future),
        throwsA(isA<ServerError>()),
      );
    });

    test('refresh() reloads earnings', () async {
      final first = _fakeEarnings(total: 1000);
      final second = _fakeEarnings(total: 3000, entries: [_fakeEntry()]);
      when(() => mockRepo.getEarnings())
          .thenAnswer((_) async => first)
          .thenAnswer((_) async => second);

      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(agentEarningsControllerProvider.future);

      // Override to return second value on next call
      when(() => mockRepo.getEarnings()).thenAnswer((_) async => second);

      await container
          .read(agentEarningsControllerProvider.notifier)
          .refresh();

      final result =
          await container.read(agentEarningsControllerProvider.future);
      expect(result.totalCommissionPaise, 3000);
      expect(result.entries.length, 1);
    });

    test('refresh() sets AsyncLoading before resolving', () async {
      final earnings = _fakeEarnings();
      when(() => mockRepo.getEarnings()).thenAnswer((_) async => earnings);

      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(agentEarningsControllerProvider.future);

      // Set up a slow second call
      when(() => mockRepo.getEarnings()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return earnings;
      });

      // Start refresh without awaiting
      final refreshFuture =
          container.read(agentEarningsControllerProvider.notifier).refresh();

      // Should be loading
      expect(
        container.read(agentEarningsControllerProvider),
        isA<AsyncLoading<AgentEarnings>>(),
      );

      await refreshFuture;
    });

    test('refresh() handles NetworkError gracefully', () async {
      final earnings = _fakeEarnings();
      when(() => mockRepo.getEarnings()).thenAnswer((_) async => earnings);

      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(agentEarningsControllerProvider.future);

      when(() => mockRepo.getEarnings())
          .thenThrow(const NetworkError(message: 'offline'));

      await container
          .read(agentEarningsControllerProvider.notifier)
          .refresh();

      expect(
        container.read(agentEarningsControllerProvider),
        isA<AsyncError<AgentEarnings>>(),
      );
    });

    test('totalCommissionDisplay comes from server — never computed by client',
        () async {
      // Backend returns pre-formatted string; client must pass it through unchanged.
      final earnings = AgentEarnings(
        totalCommissionPaise: 123456,
        totalCommissionDisplay: '₹1,234.56', // server-formatted
        entries: [],
      );
      when(() => mockRepo.getEarnings()).thenAnswer((_) async => earnings);

      final container = makeContainer();
      addTearDown(container.dispose);

      final result =
          await container.read(agentEarningsControllerProvider.future);

      // Client must not reformat — just display what server returns
      expect(result.totalCommissionDisplay, '₹1,234.56');
    });
  });
}
