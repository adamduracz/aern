{-|
    Module      :  Main
    Description :  run all tests defined in the AERN-Real package  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
-}
module Main where

import Numeric.AERN.Basics.Granularity
import Numeric.AERN.RealArithmetic.Basis.Double
import Numeric.AERN.RealArithmetic.Interval.Double

import Test.Framework (defaultMain)

main =
    do
    initGranularityRounding (0 :: Double) 
    defaultMain tests

tests = 
    [
       -- Double:
       testsDoubleComparison, testsDoubleSemidecidableComparison,
       testsDoubleLattice, testsDoubleRoundedLattice,
       -- DI:
       testsDIConsistencyFlip,
       testsDINumericSemidecidableComparison,
       testsDINumericLattice,
       testsDINumericRefinementRoundedLattice,
       testsDIRefinementSemidecidableComparison, 
       testsDIRefinementBasis,
       testsDIRefinementRoundedBasis,
       testsDIRefinementLattice,
       testsDIRefinementRoundedLattice
    ]