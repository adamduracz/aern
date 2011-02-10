
module Main where

import qualified Numeric.AERN.RmToRn.Basis.Polynomial.DoubleCoeff as DCPoly

import Numeric.AERN.RmToRn.Domain
import Numeric.AERN.RmToRn.New
import Numeric.AERN.Basics.Interval
import Numeric.AERN.Basics.ShowInternals

main :: IO ()
main =
    do
    putStrLn $ "x = " ++ showP x
    putStrLn $ "y = " ++ showP y
    where
    showP = showInternals (showChebTerms, showCoeffInternals)
    showChebTerms = True
    showCoeffInternals = False
    domainBox = fromAscList $ [(0, unitInterval),(1, unitInterval),(2, unitInterval)]
    unitInterval = Interval (-1) 1
    x = newProjection Nothing (10,3) domainBox 0 :: DCPoly.PolyFP
    y = newProjection Nothing (10,3) domainBox 1 :: DCPoly.PolyFP
    
    