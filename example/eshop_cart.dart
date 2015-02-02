// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library goap.example.eshop_cart;

import 'package:goap/goap.dart';
import 'dart:collection';
import 'dart:async';

class EshopCartPlanner {
  Planner _planner = new Planner();

  var origin = new EshopCartState();
  var goal = new EshopCartDesired();

  var userWillLogin = false;
  var userHasPaymentInfoSaved = true;
  var invoiceSameAsShipping = true;

  Iterable<EshopCartModule> actions;

  EshopCartPlanner() {
    origin.isUs = false;
    origin.needsShippingAddress = true;
    origin.needsInvoiceAddress = true;
    origin.shipsToUsOnly = true;

    actions = <EshopCartModule>[
      new EshopCartModule("Name", (EshopCartState s) {
        s.haveName = true;
      }),

      new EshopCartModule("Country", (EshopCartState s) {
        s.haveCountry = true;
      },
      prerequisite: (EshopCartState s) => s.needsShippingAddress),

      new EshopCartModule("Zip Code", (EshopCartState s) {
        s.haveZipcode = true;
      },
      prerequisite: (EshopCartState s) => s.haveCountry),

      new EshopCartModule("US State", (EshopCartState s) {
        s.haveUsState = true;
      },
      prerequisite: (EshopCartState s) => s.haveCountry && s.isUs),

      new EshopCartModule("City", (EshopCartState s) {
        s.haveCity = true;
      },
      prerequisite: (EshopCartState s) => s.haveStreet),


      new EshopCartModule("Confirm City (guessed from ZIP)", (EshopCartState s) {
        s.haveCity = true;
      },
      prerequisite: (EshopCartState s) => s.haveZipcode && s.haveStreet,
      cost: 0.1),

      new EshopCartModule("Street", (EshopCartState s) {
        s.haveStreet = true;
      },
      prerequisite: (EshopCartState s) => s.haveName),

      new EshopCartModule("Confirm Shipping Address", (EshopCartState s) {
        s.shippingAddressConfirmed = true;
      },
      prerequisite: (EshopCartState s) => s.haveShippingAddress,
      cost: 1),

      new EshopCartModule("Invoice Address", (EshopCartState s) {
        s.haveInvoiceAddress = true;
      },
      prerequisite: (EshopCartState s) => s.needsInvoiceAddress &&
          (s.haveShippingAddress || !s.needsShippingAddress),
      cost: 1),

      new EshopCartModule("Invoice Address (copied from shipping)",
          (EshopCartState s) {
        s.haveInvoiceAddress = true;
      },
      prerequisite: (EshopCartState s) =>
          s.needsInvoiceAddress && s.haveShippingAddress && invoiceSameAsShipping,
      cost: 0.1),

      new EshopCartModule("Confirm Invoice Address", (EshopCartState s) {
        s.invoiceAddressConfirmed = true;
      },
      prerequisite: (EshopCartState s) => s.haveInvoiceAddress,
      cost: 1),

      new EshopCartModule("Payment Info", (EshopCartState s) {
        s.havePaymentInfo = true;
      },
      prerequisite: (EshopCartState s) =>
          (s.haveInvoiceAddress || !s.needsInvoiceAddress) &&
          (s.haveShippingAddress || !s.needsShippingAddress)),


      new EshopCartModule("Confirm Payment Info", (EshopCartState s) {
        s.paymentInfoConfirmed = true;
      },
      prerequisite: (EshopCartState s) =>
          s.havePaymentInfo,
      cost: 1),

      new EshopCartModule("Log In", (EshopCartState s) {
        if (!userWillLogin) return;
        s.loggedIn = true;
        s.haveName = true;
        s.haveCountry = true;
        s.haveZipcode = true;
        s.haveUsState = true;
        s.haveCity = true;
        s.haveStreet = true;
        s.haveInvoiceAddress = true;
        s.havePaymentInfo = userHasPaymentInfoSaved;
        // TODO: set according to setup
      }),

      new EshopCartModule("Confirm Price", (EshopCartState s) {
        s.priceConfirmed = true;
      },
      prerequisite: (EshopCartState s) =>
              !s.isFree && s.havePaymentInfo,
      cost: 1),

      new EshopCartModule("Confirm Everything", (EshopCartState s) {
        s.shippingAddressConfirmed = true;
        s.invoiceAddressConfirmed = true;
        s.paymentInfoConfirmed = true;
        s.priceConfirmed = true;
      },
      prerequisite: (EshopCartState s) =>
          (s.haveShippingAddress || !s.needsShippingAddress) &&
          (((s.haveInvoiceAddress || !s.needsInvoiceAddress) &&
            s.havePaymentInfo) || s.isFree),
      cost: 1),

      new EshopCartModule("Finish Order", (EshopCartState s) {
        s.orderFinished = true;
      },
      prerequisite: (EshopCartState s) =>
          (s.shippingAddressConfirmed || !s.needsShippingAddress) &&
          ((s.paymentInfoConfirmed && s.priceConfirmed) || s.isFree),
      cost: 0.5
      ),

      new EshopCartModule("Will Not Ship (non-US)", (EshopCartState s) {
        s.orderFinished = true;
      },
      prerequisite: (EshopCartState s) =>
          (!s.isUs && s.shipsToUsOnly && s.haveCountry),
      cost: 0.5
      )

    ];
  }

  Future<Queue<Action>> plan() {
    return _planner.plan(origin, goal, actions,
        singleUseActions: true);
    //  previouslyFailedAction: stealGold,
    //  countdownFailedActionAvoidance: -1);
  }


}

class EshopCartModule extends Action {
  final String name;
  EshopCartModule(this.name, EshopCartApplyAction applyFunction, {num cost: 1,
    ApplicabilityFunction prerequisite}) : super(applyFunction, cost: cost,
        prerequisite: prerequisite);

  toString() => "EshopCartModule<$name>";
}

typedef void EshopCartApplyAction(EshopCartState state);

class EshopCartState extends State {
  // Info about the customer.
  bool haveName = false;
  bool haveCountry = false;
  bool isUs = true;
  bool haveZipcode = false;
  bool haveUsState = false;
  bool haveCity = false;
  bool haveStreet = false;
  bool get haveShippingAddress => haveName && haveCountry && haveZipcode &&
      haveCity && haveStreet && (isUs ? (haveUsState) : (true));
  bool shippingAddressConfirmed = false;
  bool haveInvoiceAddress = false;
  bool invoiceAddressConfirmed = false;
  bool havePaymentInfo = false;
  bool paymentInfoConfirmed = false;
  bool loggedIn = false;

  // Info about the order.
  bool priceConfirmed = false;
  num cost = 1;
  bool get isFree => cost == 0;
  bool needsShippingAddress = true;
  bool needsInvoiceAddress = true;
  bool shipsToUsOnly = false;
  bool orderFinished = false;

  EshopCartState();

  EshopCartState._internal(this.haveName, this.haveCountry,
      this.isUs, this.haveZipcode, this.haveUsState, this.haveCity,
      this.haveStreet, this.shippingAddressConfirmed, this.haveInvoiceAddress,
      this.invoiceAddressConfirmed, this.havePaymentInfo,
      this.paymentInfoConfirmed, this.loggedIn, this.orderFinished,
      this.priceConfirmed, this.cost, this.needsShippingAddress,
      this.needsInvoiceAddress, this.shipsToUsOnly);

  @override
  EshopCartState clone() => new EshopCartState._internal(haveName, haveCountry,
      isUs, haveZipcode, haveUsState, haveCity, haveStreet,
      shippingAddressConfirmed, haveInvoiceAddress, invoiceAddressConfirmed,
      havePaymentInfo, paymentInfoConfirmed, loggedIn, orderFinished,
      priceConfirmed, cost, needsShippingAddress, needsInvoiceAddress,
      shipsToUsOnly);
}

class EshopCartDesired extends DesiredState<EshopCartState> {
  @override
  num getHeuristicDistanceFrom(EshopCartState s, {Object params}) {
    // If we want breadth-first search, just return 1. _Very_ expensive.
    // return 1;
    return _cnt(s.haveCountry) + _cnt(s.havePaymentInfo) +
        _cnt(s.paymentInfoConfirmed) + _cnt(s.haveInvoiceAddress) +
        _cnt(s.haveName) + _cnt(s.haveShippingAddress) +
        _cnt(s.haveStreet) + _cnt(s.haveUsState) + _cnt(s.haveZipcode) +
        _cnt(s.invoiceAddressConfirmed) + _cnt(s.loggedIn) +
        _cnt(s.priceConfirmed) + _cnt(s.shippingAddressConfirmed) +
        _cnt(s.orderFinished);
  }

  /// Counts false as 1. Used to count the flags that are still missing.
  int _cnt(bool b) => b ? 0 : 1;

  @override
  bool match(EshopCartState state) => state.orderFinished == true;
}

main() {

  var planner = new EshopCartPlanner();
  planner.plan().then((solution) {
    print(solution.length);
    for (EshopCartModule action in solution) {
      print("State heuristic distance: ${planner.goal.getHeuristicDistanceFrom(planner.origin)}");
      print(">> ${action.name}");
      planner.origin = action.createNewNodeFrom(planner.origin);
    }
    print(planner.origin);
  });
}
