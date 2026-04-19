import 'package:Storia_Kids/src/features/child/data/child_profile_repository.dart';
import 'package:Storia_Kids/src/features/child/domain/child_profile.dart';
import 'package:Storia_Kids/src/features/child/providers/active_child_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChildProfileRepository implements ChildProfileRepository {
  _FakeChildProfileRepository({
    List<ChildProfile> profiles = const [],
    this.savedActiveChildId,
    this.throwOnCreate = false,
  }) : _profiles = List.of(profiles);

  final List<ChildProfile> _profiles;
  String? savedActiveChildId;
  bool throwOnCreate;
  CreateChildProfileInput? capturedCreateInput;

  @override
  Future<ChildProfile> createChildProfile(CreateChildProfileInput input) async {
    if (throwOnCreate) {
      throw StateError('create failed');
    }

    capturedCreateInput = input;
    if (input.isDefault) {
      for (var index = 0; index < _profiles.length; index++) {
        final profile = _profiles[index];
        _profiles[index] = ChildProfile(
          id: profile.id,
          displayName: profile.displayName,
          ageBand: profile.ageBand,
          readingLevel: profile.readingLevel,
          isDefault: false,
          createdAt: profile.createdAt,
          updatedAt: profile.updatedAt,
        );
      }
    }

    final created = ChildProfile(
      id: 'child-${_profiles.length + 1}',
      displayName: input.displayName,
      ageBand: input.ageBand,
      readingLevel: input.readingLevel,
      isDefault: input.isDefault,
    );
    _profiles.add(created);
    return created;
  }

  @override
  Future<ChildProfile?> fetchDefaultChildProfile() async {
    return resolveActiveChild(_profiles);
  }

  @override
  Future<List<ChildProfile>> fetchChildProfiles() async {
    return List.unmodifiable(_profiles);
  }

  @override
  Future<ChildProfile?> resolveActiveChild(List<ChildProfile> profiles) async {
    if (profiles.isEmpty) return null;

    final saved = profiles.where((p) => p.id == savedActiveChildId).firstOrNull;
    if (saved != null) return saved;

    return profiles.where((p) => p.isDefault).firstOrNull ?? profiles.first;
  }

  @override
  Future<void> saveActiveChildId(String childProfileId) async {
    savedActiveChildId = childProfileId;
  }
}

void main() {
  test('CreateChildProfileInput trims fields and nulls blank readingLevel', () {
    const input = CreateChildProfileInput(
      displayName: '  Ava  ',
      ageBand: ' 7-9 ',
      readingLevel: '   ',
      isDefault: true,
    );

    expect(input.toJson(), {
      'displayName': 'Ava',
      'ageBand': '7-9',
      'readingLevel': null,
      'isDefault': true,
    });
  });

  test('build prefers the saved active child when it still exists', () async {
    final repo = _FakeChildProfileRepository(
      profiles: const [
        ChildProfile(
          id: 'child-1',
          displayName: 'Mia',
          ageBand: '4-6',
          isDefault: true,
        ),
        ChildProfile(
          id: 'child-2',
          displayName: 'Ava',
          ageBand: '7-9',
          isDefault: false,
        ),
      ],
      savedActiveChildId: 'child-2',
    );
    final container = ProviderContainer(
      overrides: [
        childProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final activeChild = await container.read(activeChildProvider.future);
    expect(activeChild?.id, 'child-2');
  });

  test('createChild selects created child and refreshes child list', () async {
    final repo = _FakeChildProfileRepository(
      profiles: const [
        ChildProfile(
          id: 'child-1',
          displayName: 'Mia',
          ageBand: '4-6',
          isDefault: true,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        childProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(activeChildProvider.future);
    expect(initial?.id, 'child-1');

    final created = await container.read(activeChildProvider.notifier).createChild(
      const CreateChildProfileInput(
        displayName: 'Ava',
        ageBand: '7-9',
        readingLevel: null,
        isDefault: false,
      ),
    );

    expect(created.id, 'child-2');
    expect(container.read(activeChildProvider).valueOrNull?.id, 'child-2');
    expect(repo.savedActiveChildId, 'child-2');

    final profiles = await container.read(childProfilesProvider.future);
    expect(profiles.map((p) => p.id), ['child-1', 'child-2']);
  });

  test('createChild keeps existing active child when creation fails', () async {
    final repo = _FakeChildProfileRepository(
      profiles: const [
        ChildProfile(
          id: 'child-1',
          displayName: 'Mia',
          ageBand: '4-6',
          isDefault: true,
        ),
      ],
      throwOnCreate: true,
    );
    final container = ProviderContainer(
      overrides: [
        childProfileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeChildProvider.future);

    expect(
      () => container.read(activeChildProvider.notifier).createChild(
        const CreateChildProfileInput(
          displayName: 'Ava',
          ageBand: '7-9',
          readingLevel: 'Level 2',
          isDefault: false,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(container.read(activeChildProvider).valueOrNull?.id, 'child-1');
    final profiles = await container.read(childProfilesProvider.future);
    expect(profiles, hasLength(1));
  });
}
