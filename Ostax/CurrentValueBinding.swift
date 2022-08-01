//
//  CurrentValueBinding.swift
//  Ostax
//
//  Created by Juha Paananen on 1.8.2022.
//

import Combine
import SwiftUI

extension CurrentValueSubject {
  var binding: Binding<Output> {
    Binding(get: {
      self.value
    }, set: {
      self.send($0)
    })
  }
}
