// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library goap.example;

import 'package:goap/goap.dart';

class LumberjackAction extends Action {
  final String name;
  LumberjackAction(this.name, ApplyAction applyFunction, {num cost: 1,
    ApplicabilityFunction prerequisite}) : super(applyFunction, cost: cost,
        prerequisite: prerequisite);

  toString() => name;
}

class LumberjackDream extends DesiredState<SimpleState> {
  @override
  num getHeuristicDistanceFrom(SimpleState node, {Object params}) {
    return 100 - node.facts["gold"];
  }

  @override
  bool match(SimpleState node) => node.facts["gold"] >= 100;
}

main() {
  var planner = new Planner();

  var origin = new SimpleState()
  ..facts = {
    "gold": 10,
    "lumber": 0,
    "axe": false,
    "improvedAxe": false
  };

  var goal = new LumberjackDream();

  var buyAxe = new LumberjackAction("BuyAxe", (SimpleState state) {
    state.facts["gold"] -= 10;
    state.facts["axe"] = true;
  }, prerequisite: (SimpleState state) => state.facts["gold"] >= 10);

  var improveAxe = new LumberjackAction("ImproveAxe", (SimpleState state) {
    state.facts["gold"] -= 1;
    state.facts["improvedAxe"] = true;
  }, prerequisite: (SimpleState state) => state.facts["axe"] == true &&
      state.facts["gold"] > 1);

  var chopWood = new LumberjackAction("ChopWood", (SimpleState state) {
    state.facts["lumber"] += 10;
  }, prerequisite: (SimpleState state) => state.facts["axe"] == true,
      cost: 5);

  var chopWoodBetter = new LumberjackAction("ChopWoodBetter", (SimpleState state) {
    state.facts["lumber"] += 10;
  }, prerequisite: (SimpleState state) => state.facts["axe"] == true &&
      state.facts["improvedAxe"]);

  var sellWood = new LumberjackAction("SellWood", (SimpleState state) {
    state.facts["lumber"] -= 7;
    state.facts["gold"] += 10;
  }, prerequisite: (SimpleState state) => state.facts["lumber"] >= 7);

  var stealGold = new LumberjackAction("StealGold", (SimpleState s) {
    s.facts["gold"] += 50;
  });

  var solution = planner.plan(origin, goal, [buyAxe, improveAxe, chopWood,
                                             chopWoodBetter, sellWood,
                                             stealGold],
                                             previouslyFailedAction: stealGold,
                                             countdownFailedActionAvoidance: -1);
  solution.then((solution) {

    print(solution.length);
    for (LumberjackAction action in solution) {
      print(origin);
      print(action);
      origin = action.createNewNodeFrom(origin);
    }
    print(origin);
  });
}
