Native = require 'native'

describe "Native", ->
  nativeModule = null

  beforeEach ->
    nativeModule = new Native
