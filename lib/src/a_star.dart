/**
 * Custom version of the generic A* algorithm over at the Dart a_star package.
 *
 */

library goap.a_star;

import 'dart:collection';
import 'dart:async';

/**
 * Mixin class with which the nodes (graph vertices) should be extended. For
 * example:
 *
 *     class MyMapTile extends Object with Node { /* ... */ }
 *
 * Or, in some cases, your graph nodes will already be extending something
 * else, so:
 *
 *     class MyTraversableTile extends MyTile with Node { /* ... */ }
 */
class Node extends Object {
  num _f;
  num _g;
  Node _parent;
  EdgeType _arrivalMethod;
  bool _isInOpenSet = false;  // Much faster than finding nodes in iterables.
  bool _isInClosedSet = false;
}

/**
 * [EdgeType] is a "way of traveling" from one [Node] to another. When given
 * a node and a set of edge types, one can construct the edges that lead
 * from that node (by calling [createNewNodeFrom]).
 *
 * For example, in a 2D tile map, there would be 8 edge types, one for every
 * direction (north, northeast, east, southeast, and so on).
 */
abstract class EdgeType<T extends Node> {
  /// Takes [node] and returns the node that results from traversing / using
  /// the edge type from that node.
  T createNewNodeFrom(T node);

  /// Returns [:true:] if the edge type is applicable to the [node].
  bool applicable(T node, Object params);

  /// The cost of traversing through this edge type.
  num cost;
}

/// Implement this class to give the A* search a goal.
abstract class GoalMatcher<T extends Node> {
  /// Returns [:true:] when [node] matches the goal.
  bool match(T node);

  /// Returns the heuristic distance from [node] to the goal.
  num getHeuristicDistanceFrom(T node, {Object params});
}

/// Simple implementation of [GoalMatcher]. This one only matches one node
/// ([goal]) and it gets its heuristic distances through calling the
/// [getCostFunction] closure.
class SimpleGoalMatcher<T extends Node> extends GoalMatcher<T> {
  SimpleGoalMatcher(this.goal, this.getCostFunction);
  final T goal;
  final GetCostFunction getCostFunction;

  @override
  bool match(T node) => goal == node;

  @override
  num getHeuristicDistanceFrom(T node, {Object params}) {
    return getCostFunction(node, goal, params);
  }
}

typedef Iterable<Node> GetNeighboursFunction(Node node, Object params);
typedef Iterable<EdgeType> GetWaysFunction(Node node, Object params);
typedef num GetCostFunction(Node a, Node b, Object params);

/**
 * The A* Star algorithm itself.
 */
class AStar<T extends Node, S extends EdgeType> {
  Set<T> allNodes = new Set<T>();

  AStar();
  // TODO: freeMemory() -- by default, the algorithm keeps around the Nodes
  // it has visited. This could create memory leaks if you reuse the same AStar
  // too many times.

  bool _zeroed = true;

  static final Queue EMPTY_PATH = new Queue();

  void _zeroNodes() {
    allNodes.forEach((Node node) {
      node._isInClosedSet = false;
      node._isInOpenSet = false;
      node._parent = null;
      node._arrivalMethod = null; // TODO: nulling needed?
      // No need to zero out f and g, A* doesn't depend on them being set
      // to 0 (it overrides them on first access to each node).
    });
    _zeroed = true;
  }

  /**
   * Perform A* search from [start] to [goal] asynchronously.
   *
   * Returns a [Future] that completes with the path [Queue]. (Empty [Queue]
   * means no valid path from start to goal was found.
   *
   * TODO: Optional weighing for suboptimal, but faster path finding.
   * http://en.wikipedia.org/wiki/A*_search_algorithm#Bounded_relaxation
   */
  Future<Queue<S>> findPath(T start, GoalMatcher goalMatcher,
      Iterable<S> traversalWays, {bool singleUseWays: false, Object params}) {
    return new Future<Queue<S>>(
        () => findPathSync(start, goalMatcher, traversalWays,
            singleUseWays: singleUseWays, params: params));
  }

  /**
   * Perform A* search from [start] to [goal]. You can optionally add [params]
   * that are passed through to [Graph.getDistance],
   * [Graph.getHeuristicDistance] and [Graph.getNeighboursOf].
   *
   * Returns [:null:] when there is no path between the two nodes.
   *
   * TODO: Optional weighing for suboptimal, but faster path finding.
   * http://en.wikipedia.org/wiki/A*_search_algorithm#Bounded_relaxation
   */
  Queue<S> findPathSync(T start, GoalMatcher goalMatcher,
                        Iterable<S> traversalWays,
                        {bool singleUseWays: false, Object params}) {
    return _findPathInternal(start, goalMatcher, traversalWays,
        singleUseWays, params);
  }

  Queue<S> _findPathInternal(T start, GoalMatcher goalMatcher,
      Iterable<S> traversalWays, bool singleUseWays, Object params) {
    if (!_zeroed) _zeroNodes();

    final Queue<T> open = new Queue<T>();
    Node lastClosed;

    open.add(start);
    start._isInOpenSet = true;
    start._f = -1.0;
    start._g = -1.0;

    _zeroed = false;

    while (open.isNotEmpty) {
      // Find node with best (lowest) cost.
      T currentNode = open.fold(null, (T a, T b) {
        if (a == null) return b;
        return a._f < b._f ? a : b;
      });

      if (goalMatcher.match(currentNode)) {
        final Queue<S> path = new Queue<S>();

        // Go up the chain to recreate the path
        while (currentNode._arrivalMethod != null) {
          path.addFirst(currentNode._arrivalMethod);
          currentNode = currentNode._parent;
        }

        return path;  // TODO: return something when already there (no path, but success!)
      }

      open.remove(currentNode);
      currentNode._isInOpenSet = false;  // Much faster than finding nodes
                                         // in iterables.
      lastClosed = currentNode;
      currentNode._isInClosedSet = true;

      Set<T> candidates = new Set<T>();

      // Get only ways that are applicable and (if singleUseWays is true) also
      // that haven't been used previously.
      Iterable<S> applicableWays = traversalWays
          .where((S way) => way.applicable(currentNode, params) &&
                 (!singleUseWays || _wayNotInParents(way, currentNode)));

      for (S way in applicableWays) {
        T node = way.createNewNodeFrom(currentNode);
        node._arrivalMethod = way;
        candidates.add(node);
        allNodes.add(node);
      }

      for (final T candidate in candidates) {
        num distance = candidate._arrivalMethod.cost;

        if (distance != null || (goalMatcher.match(candidate))) {
          // If the new node is open or the new node is our destination.
          if (candidate._isInClosedSet) {
            continue;
          }

          if (!candidate._isInOpenSet) {
            candidate._parent = lastClosed;

            candidate._g = currentNode._g + distance;
            num h = goalMatcher.getHeuristicDistanceFrom(candidate,
                params: params);
            candidate._f = candidate._g + h;

            open.add(candidate);
            candidate._isInOpenSet = true;
          }
        }
      }
    }

    // No path found.
    return null;
  }

  /// Checks that no parent of [currentNode] was traversed to by [way]. This is
  /// used when searching for paths that only allow any [EdgeType] to be
  /// used once.
  bool _wayNotInParents(S way, T currentNode) {
    while (currentNode._parent != null) {
      if (currentNode._arrivalMethod == way) return false;
      currentNode = currentNode._parent;
    }
    return true;
  }

}
