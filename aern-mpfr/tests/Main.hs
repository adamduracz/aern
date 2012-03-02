{-# LANGUAGE TypeFamilies #-}
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

import Numeric.AERN.RealArithmetic.Basis.MPFR
import Numeric.AERN.RealArithmetic.Interval.MPFR
import Numeric.AERN.RealArithmetic.Interval
import Numeric.AERN.RealArithmetic.Interval.Mutable
-- import Numeric.AERN.RealArithmetic.Interval.ElementaryDirect
import Numeric.AERN.RealArithmetic.Interval.ElementaryFromBasis
import Numeric.AERN.Basics.Interval

import Numeric.AERN.Basics.Consistency
import qualified Numeric.AERN.NumericOrder as NumOrd
import qualified Numeric.AERN.RefinementOrder as RefOrd

import Numeric.AERN.RealArithmetic.Measures
import qualified Numeric.AERN.RealArithmetic.NumericOrderRounding as ArithUpDn
import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut

import Test.Framework (defaultMain)

main =
    do
    defaultMain tests

tests = testsMPFR ++ testsMI

testsMPFR =
    [
--       NumOrd.testsArbitraryTuple ("MPFR", sampleM, NumOrd.compare),
       NumOrd.testsPartialComparison ("MPFR", sampleM) areaN,
       NumOrd.testsRoundedLatticeDistributive ("MPFR", sampleM) areaN,
       testsDistance ("MPFR", sampleM),
       ArithUpDn.testsConvert ("MPFR", sampleM, "Integer", sampleI),
       ArithUpDn.testsConvert ("Integer", sampleI, "MPFR", sampleM),
       ArithUpDn.testsConvert ("MPFR", sampleM, "Rational", sampleR),
       ArithUpDn.testsConvert ("Rational", sampleR, "MPFR", sampleM),
       ArithUpDn.testsConvert ("Double", sampleD, "MPFR", sampleM),
       ArithUpDn.testsConvert ("MPFR", sampleM, "Double", sampleD),
       ArithUpDn.testsUpDnAdd ("MPFR", sampleM),
       ArithUpDn.testsUpDnSubtr ("MPFR", sampleM),
       ArithUpDn.testsUpDnAbs ("MPFR", sampleM),
       ArithUpDn.testsUpDnMult ("MPFR", sampleM),
       ArithUpDn.testsUpDnIntPower ("MPFR", sampleM),
       ArithUpDn.testsUpDnDiv ("MPFR", sampleM),
       ArithUpDn.testsUpDnFieldOpsInPlace ("MPFR", sampleM),
       ArithUpDn.testsUpDnMixedFieldOps ("MPFR", sampleM) ("Integer", sampleI),
       ArithUpDn.testsUpDnMixedFieldOps ("MPFR", sampleM) ("Rational", sampleR),
       ArithUpDn.testsUpDnMixedFieldOps ("MPFR", sampleM) ("Double", sampleD),
       ArithUpDn.testsUpDnMixedFieldOpsInPlace ("MPFR", sampleM) ("Integer", sampleI),
       ArithUpDn.testsUpDnMixedFieldOpsInPlace ("MPFR", sampleM) ("Rational", sampleR),
       ArithUpDn.testsUpDnMixedFieldOpsInPlace ("MPFR", sampleM) ("Double", sampleD),
       ArithUpDn.testsUpDnExp ("MPFR", sampleM)
    ]

testsMI =
    [
       testsConsistency ("MI", sampleMI),
       NumOrd.testsPartialComparison ("MI", sampleMI) areaNInterval,
       NumOrd.testsRefinementRoundedLatticeDistributiveMonotone ("MI", sampleMI) areaNInterval areaR,
       NumOrd.testsRefinementRoundedLatticeInPlace ("MI", sampleMI),
       RefOrd.testsPartialComparison  ("MI", sampleMI) areaR, 
       RefOrd.testsRoundedBasis ("MI", sampleMI),
       RefOrd.testsRoundedLatticeDistributive ("MI", sampleMI) areaR,
       testsDistance ("MI", sampleMI),
       testsImprecision ("MI", sampleMI),
       ArithInOut.testsConvertNumOrd ("Integer", sampleI, "MI", sampleMI),
       ArithInOut.testsConvertNumOrd ("Double", sampleD, "MI", sampleMI),
       ArithInOut.testsConvertNumOrd ("Rational", sampleR, "MI", sampleMI),
       ArithInOut.testsInOutAdd ("MI", sampleMI) areaR,
       ArithInOut.testsInOutSubtr ("MI", sampleMI) areaR,
       ArithInOut.testsInOutAbs ("MI", sampleMI) areaR,
       ArithInOut.testsInOutMult ("MI", sampleMI) areaR,
       ArithInOut.testsInOutIntPower ("MI", sampleMI) areaR,
       ArithInOut.testsInOutDiv ("MI", sampleMI) areaR,
       ArithInOut.testsInOutFieldOpsInPlace ("MI", sampleMI),
       ArithInOut.testsInOutMixedFieldOps ("MI", sampleMI) ("Integer", sampleI) areaR,
       ArithInOut.testsInOutMixedFieldOps ("MI", sampleMI) ("Rational", sampleR) areaR,
       ArithInOut.testsInOutMixedFieldOps ("MI", sampleMI) ("Double", sampleD) areaR,
       ArithInOut.testsInOutMixedFieldOpsInPlace ("MI", sampleMI) ("Integer", sampleI),
       ArithInOut.testsInOutMixedFieldOpsInPlace ("MI", sampleMI) ("Rational", sampleR),
       ArithInOut.testsInOutMixedFieldOpsInPlace ("MI", sampleMI) ("Double", sampleD)
       ,
       ArithInOut.testsInOutExp ("MI", sampleMI),
       ArithInOut.testsInOutSqrt ("MI", sampleMI) unPositiveMI
    ]

areaN = NumOrd.areaWhole sampleM
areaNInterval = NumOrd.areaWhole sampleMI
areaR = RefOrd.areaWhole sampleMI

sampleD = 1 :: Double
sampleI = 1 :: Integer
sampleR = 1 :: Rational