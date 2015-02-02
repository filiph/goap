// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library goap.base;

import 'a_star.dart';
import 'dart:collection';
import 'dart:async';

abstract class State extends Object with Node {
  State clone();
}

/**
 * Like [State], but it doesn't need to have all the facts and when computing
 * distance, it only takes into account the facts that it has.
 */
abstract class DesiredState<T extends State> extends GoalMatcher<T> {
}

class SimpleStateFactMap {
  Map<String,dynamic> facts;
}

class SimpleState extends State with SimpleStateFactMap {
  State clone() {
    SimpleState clone = new SimpleState();
    clone.facts = new Map<String,Object>.from(facts);
    return clone;
  }

  toString() => "SimpleState[$facts]";
}

class SimpleDesiredState extends DesiredState with SimpleStateFactMap {
  @override
  num getHeuristicDistanceFrom(SimpleState node, {FindPathParams params}) {
    num result = 0;
    Set stateKeys = _getMapKeysUnion(facts, node.facts);
    for (var key in stateKeys) {
      if (!facts.containsKey(key) || !node.facts.containsKey(key)) {
        continue;
      } else if (facts[key] != node.facts[key]) {
        var value = facts[key];
        var otherValue = node.facts[key];
        if (value is num && otherValue is num) {
          result += ((value as int) - (otherValue as int)).abs();
        } else {
          result += DEFAULT_COST;
        }
      }
    }
    return result;
  }

  @override
  bool match(SimpleState node) {
    for (String key in facts.keys) {
      if (!node.facts.containsKey(key)) return false;
      if (facts[key] != node.facts[key]) return false;
    }
    return true;
  }

  static const num DEFAULT_COST = 1;
}

class Action<T extends State> extends EdgeType<T> {
  // TODO: add GOAP-style non-procedural pre-requisites and effects.
  //       (a fixed sized array for each?)

  Action(this.applyFunction, {num cost: 1, this.prerequisite}) {
    this.cost = cost;
  }

  /// Returns the state that results from performing [Action] while
  /// being at [originalState]. This changes the original state **in place**.
  final ApplyAction applyFunction;

  /// Prerequisite. Checks whether the action can be applied to given State.
  final ApplicabilityFunction prerequisite;

  /// Cost of this action.
//  num cost = 1;

  @override
  T createNewNodeFrom(T node) {
    T newState = node.clone();
    applyFunction(newState);
    return newState;
  }

  @override
  bool applicable(T state, Object params) {
    if (params != null && params is FindPathParams &&
        params.previouslyFailedAction == this) {
      if (params.countdownFailedActionAvoidance == -1) return false;
      assert(params.countdownFailedActionAvoidance != 0);
      params.countdownFailedActionAvoidance -= 1;
      if (params.countdownFailedActionAvoidance == 0) {
        params.previouslyFailedAction = null;
      }
      return false;
    }
    if (prerequisite == null) return true;
    return prerequisite(state);
  }
}

typedef bool ApplicabilityFunction(State state);
typedef void ApplyAction(State state);

class FindPathParams {
  FindPathParams(this.availableActions, this.previouslyFailedAction);
  final Set<Action> availableActions;
  Action previouslyFailedAction;
  /// The number of times the action is being avoided before it's tried again.
  /// Set to [:-1:] to avoid the action for the whole time of path finding.
  int countdownFailedActionAvoidance = 1;
}

class Planner {
  Planner();

  /// Plan a sequence of action that bring you from [origin] to [desiredState]
  /// using [actions].
  ///
  /// Failed action parameters are for replanning. Just after an action fails,
  /// we don't want to replan beginning with that same [previouslyFailedAction].
  /// We avoid it once time by default, but can avoid it for longer periods
  /// by setting [countdownFailedActionAvoidance]. Value [:-1:] is magical: it
  /// will avoid [previouslyFailedAction] for the whole duration of the plan.
  Future<Queue<Action>> plan(State origin, DesiredState desiredState,
      Iterable<Action> actions, {Action previouslyFailedAction,
        int countdownFailedActionAvoidance: 1, bool singleUseActions: false}) {
    if (actions is! Set<Action>) {
      actions = new Set<Action>.from(actions);
    }
    FindPathParams params = new FindPathParams(actions, previouslyFailedAction);
    params.countdownFailedActionAvoidance = countdownFailedActionAvoidance;
    print("Starting search.");
    return _aStar.findPath(origin, desiredState, actions,
        singleUseWays: singleUseActions, params: params);
  }

  // TODO: optional parameter (dependency injection).
  final AStar<State, Action> _aStar = new AStar<State, Action>();
}

Set _getMapKeysUnion(Map a, Map b) {
  Set stateKeys = new Set.from(a.keys);
  stateKeys = stateKeys.union(new Set.from(a.keys));
  return stateKeys;
}