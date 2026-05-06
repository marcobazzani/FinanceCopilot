/// Scope filter for pillar-aware UI. Sealed because `.pillar(id)` carries
/// a string payload, which `enum` cannot.
sealed class PillarScope {
  const PillarScope();

  const factory PillarScope.all() = PillarScopeAll;
  const factory PillarScope.unassigned() = PillarScopeUnassigned;
  const factory PillarScope.pillar(String id) = PillarScopePillar;

  T when<T>({
    required T Function() all,
    required T Function() unassigned,
    required T Function(String id) pillar,
  }) {
    final self = this;
    return switch (self) {
      PillarScopeAll() => all(),
      PillarScopeUnassigned() => unassigned(),
      PillarScopePillar(:final id) => pillar(id),
    };
  }
}

class PillarScopeAll extends PillarScope {
  const PillarScopeAll();
  @override
  bool operator ==(Object other) => other is PillarScopeAll;
  @override
  int get hashCode => 0;
}

class PillarScopeUnassigned extends PillarScope {
  const PillarScopeUnassigned();
  @override
  bool operator ==(Object other) => other is PillarScopeUnassigned;
  @override
  int get hashCode => 1;
}

class PillarScopePillar extends PillarScope {
  final String id;
  const PillarScopePillar(this.id);
  @override
  bool operator ==(Object other) =>
      other is PillarScopePillar && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
