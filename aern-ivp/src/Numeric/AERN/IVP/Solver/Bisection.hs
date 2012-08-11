{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE MultiParamTypeClasses #-}
--{-# LANGUAGE ScopedTypeVariables #-}
{-|
    Module      :  Numeric.AERN.IVP.Solver.Bisection
    Description :  adaptive splitting solver parametrised by a single-step solver  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Adaptive splitting solver parametrised by a single-step solver.
    
    Typically one uses solveODEIVPByBisectingT0 and
    its subsolver is defined using solveODEIVPByBisectingAtT0End
    and its subsolver for the right-hand side is 
    defined using solveODEIVPByBisectingT:
    
    solveODEIVPByBisectingT0
    |
    |
    solveODEIVPByBisectingAtT0End
    |       \
    |        \
    solve-VT  solveODEIVPByBisectingT
              |
              |
              solve-Vt
-}

module Numeric.AERN.IVP.Solver.Bisection
(
    solveHybridIVPByBisectingT,
    solveODEIVPByBisectingAtT0End,
    solveODEIVPByBisectingT,
    solveODEIVPByBisectingT0,
    BisectionInfo(..),
    showBisectionInfo,
    bisectionInfoCountLeafs,
    bisectionInfoGetLeafSegInfoSequence,
    checkConditionOnBisection,
    evalFnOnBisection
)
where

import Numeric.AERN.IVP.Specification.ODE
import Numeric.AERN.IVP.Specification.Hybrid

import Numeric.AERN.RmToRn.Domain
import Numeric.AERN.RmToRn.New
import Numeric.AERN.RmToRn.Evaluation
import Numeric.AERN.RmToRn.Integration

import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsImplicitEffort
--import Numeric.AERN.RealArithmetic.ExactOps
import Numeric.AERN.RealArithmetic.Measures

import qualified Numeric.AERN.NumericOrder as NumOrd
import Numeric.AERN.NumericOrder.OpsDefaultEffort

import qualified Numeric.AERN.RefinementOrder as RefOrd
import Numeric.AERN.RefinementOrder.OpsImplicitEffort

import Numeric.AERN.Basics.Consistency

--import Numeric.AERN.Basics.Exception
--import Control.Exception (throw)

--import qualified Data.Map as Map


import Data.Maybe (isJust)

import Numeric.AERN.Misc.Debug
_ = unsafePrint
        
solveHybridIVPByBisectingT ::
    (CanAddVariables f,
     CanEvaluate f,
     CanCompose f,
     HasProjections f,
     HasConstFns f,
     RefOrd.PartialComparison f,
     RoundedIntegration f,
     ArithInOut.RoundedAdd f,
     ArithInOut.RoundedMixedAdd f (Domain f),
     ArithInOut.RoundedReal (Domain f), 
     RefOrd.IntervalLike(Domain f),
     HasAntiConsistency (Domain f),
     Domain f ~ Imprecision (Domain f),
     Show f, Show (Domain f))
    =>
    (Int -> HybridIVP f -> (Maybe (HybridSystemUncertainState (Domain f)), solvingInfo)) -- ^ solver to use for segments  
    ->
    ArithInOut.RoundedRealEffortIndicator (Domain f) 
    ->
    Imprecision (Domain f) -- ^ splitting improvement threshold
    ->
    Domain f -- ^ minimum segment length  
    ->
    Domain f -- ^ maximum segment length  
    ->
    (HybridIVP f)  -- ^ problem to solve
    ->
    (
        Maybe (HybridSystemUncertainState (Domain f))
    ,
        (
            BisectionInfo solvingInfo (solvingInfo, Maybe (Imprecision (Domain f)))
        )
    )
solveHybridIVPByBisectingT
        solver
            effDom splitImprovementThreshold minStepSize maxStepSize 
                hybivpG 
    =
    result
    where
    result = splitSolve 0 hybivpG
    
    splitSolve depth hybivp =
--        unsafePrint
--        (
--            "solveHybridIVPByBisectingT: splitSolve: "
--            ++ "tStart = " ++ show tStart
--            ++ "tEnd = " ++ show tEnd
--        ) $
        result2
        where
        result2
            | belowStepSize = directComputation
            | aboveMaxStepSize = splitComputation
            | directComputationFailed = splitComputation
            | otherwise = 
                case maybeSplitImprovement of
                    Just improvementBy 
                        | (improvementBy >? splitImprovementThreshold) /= Just True -> 
                            directComputation -- split once computations succeeded but brought no noticeable improvement
                    _
                        | splitComputationFailed -> directComputation
                        | otherwise -> splitComputation -- splitting either brought noticeable improvement or some computation failed 
        tStart = hybivp_tStart hybivp
        tEnd = hybivp_tEnd hybivp
        
        belowStepSize =
            let ?addInOutEffort = effAddDom in
            ((tEnd <-> tStart) >? minStepSize) /= Just True
        aboveMaxStepSize =
            let ?addInOutEffort = effAddDom in
            ((tEnd <-> tStart) <? maxStepSize) /= Just True

        directComputation =
--            unsafePrint
--            (
--                "solveHybridIVPByBisectingT: completed time " ++ show tEnd
--            ) $
            case maybeDirectResult of
                Just resultOut 
                    | otherwise -> (Just resultOut, BisectionNoSplit directInfo)
                _ -> (Nothing, BisectionNoSplit directInfo) 
        (maybeDirectResult, directInfo) = solver depth hybivp
        directComputationFailed =
            case maybeDirectResult of Just _ -> False; _ -> True
        
        splitOnceComputation = -- needed only to decide whether splitting is benefitial, the result is then discarded
            case solver (depth + 1) hybivpL of
                (Just midState, _) ->
                    case solver (depth + 1) hybivpR of
                        (Just endStateOut, _) -> Just endStateOut 
                        _ -> Nothing
                    where
                    hybivpR =
                        hybivp
                        {
                            hybivp_tStart = tMid,
                            hybivp_initialStateEnclosure = midState
                        }
                _ -> Nothing
                
        (splitComputation, splitComputationFailed) =
            (
                (maybeState, BisectionSplit (directInfo, maybeSplitImprovement) infoL maybeInfoR)
            , 
                case maybeState of Just _ -> False; _ -> True
            )
            where
            (maybeMidState, infoL) =
                splitSolve (depth + 1) hybivpL
            (maybeState, maybeInfoR) =
                case maybeMidState of
                    Just midState ->
                        case splitSolve (depth + 1) hybivpR of
                            (maybeState2, infoR) -> (maybeState2, Just infoR)
                        where
                        hybivpR =
                            hybivp
                            {
                                hybivp_tStart = tMid,
                                hybivp_initialStateEnclosure = midState
                            }
                    Nothing -> (Nothing, Nothing)
        hybivpL =
            hybivp
            {
                hybivp_tEnd = tMid
            }
        tMid =
            getMidPoint effAddDom effDivDomInt tStart tEnd 
        
        maybeSplitImprovement =
            case (maybeDirectResult, splitOnceComputation) of
                (Just directResult, Just splitOnceResult) -> 
                    Just $ measureImprovementState sampleDom effDom directResult splitOnceResult
                _ -> Nothing

    effAddDom = ArithInOut.fldEffortAdd sampleDom $ ArithInOut.rrEffortField sampleDom effDom
    effDivDomInt = 
        ArithInOut.mxfldEffortDiv sampleDom (1 :: Int) $ 
            ArithInOut.rrEffortIntMixedField sampleDom effDom
--    effRefComp = ArithInOut.rrEffortRefComp sampleDom effDom
    sampleDom = hybivp_tStart hybivpG
--    effMinmax = ArithInOut.rrEffortMinmaxInOut sampleDom effDom
    
--    effImpr = ArithInOut.rrEffortImprecision sampleDom effDom
--    sampleImpr = imprecisionOfEff effImpr sampleDom
--    effAddImpr = ArithInOut.fldEffortAdd sampleImpr $ ArithInOut.rrEffortImprecisionField sampleDom effDom
        
solveODEIVPByBisectingAtT0End ::
    (HasAntiConsistency (Domain f), 
     HasAntiConsistency f,
     Show f, Show (Domain f))
    =>
    (ODEIVP f -> (Maybe [f], solvingInfoL)) -- ^ uncertain time solver; giving parametrised results
    -> 
    ([f] -> ODEInitialValues f) -- ^ make ODE IVP initial value specification from parametrised initial values
    -> 
    (ODEIVP f -> (Maybe [Domain f], solvingInfoR)) -- ^ exact time solver; giving wrapped results
    -> 
    ODEIVP f
    -> 
    (
        Maybe [Domain f]
    , 
        (solvingInfoL, Maybe solvingInfoR)
    )
solveODEIVPByBisectingAtT0End
        solverVT makeMakeParamInitValFnVec solverVt 
            odeivpG 
    =
    (maybeResult, (infoL, maybeInfoR))
    where
    (maybeResult, maybeInfoR) =
        case maybeResultL of
            Just fnVecLOut ->
                case maybeResultROut of
                    Just resultOut ->
--                        unsafePrint
--                        (
--                            "solveODEIVPByBisectingAtT0End:"
--                            ++ "\n fnVecLOut = " ++ show fnVecLOut
--                        )
                        (Just result, Just infoROut)
                        where
                        result = resultOut 
                    Nothing -> (Nothing, Just infoROut)
                where
                (maybeResultROut, infoROut) = solverVt odeivpROut
                odeivpROut = odeivpR fnVecLOut
                odeivpR fnVecL =
                    odeivpG
                        {
                            odeivp_tStart = t0End
                        ,
                            odeivp_makeInitialValueFnVec =
                                makeMakeParamInitValFnVec fnVecL
                        }
            _ -> 
                (Nothing, Nothing)
    (maybeResultL, infoL) = solverVT odeivpL
    odeivpL =
        odeivpG
            {
                odeivp_tEnd = t0End
            }
    t0End = odeivp_t0End odeivpG
    
solveODEIVPByBisectingT ::
    (CanAddVariables f,
     CanEvaluate f,
     CanCompose f,
     HasProjections f,
     HasConstFns f,
     RefOrd.PartialComparison f,
     RoundedIntegration f,
     ArithInOut.RoundedAdd f,
     ArithInOut.RoundedMixedAdd f (Domain f),
     ArithInOut.RoundedReal (Domain f), 
     RefOrd.IntervalLike(Domain f),
     HasAntiConsistency (Domain f),
     Domain f ~ Imprecision (Domain f),
     Show f, Show (Domain f),
     solvingInfo ~ (Maybe result, additionalInfo))
    =>
    (ODEIVP f -> solvingInfo) -- ^ solver to use for segments  
    ->
    (result -> Domain f) -- ^ measure imprecision
    ->
    (result -> ODEInitialValues f) -- ^ how to change initial conditions
    ->
    ArithInOut.RoundedRealEffortIndicator (Domain f) 
    ->
    (Domain f) -- ^ splitting improvement threshold
    ->
    Domain f -- ^ minimum segment length  
    ->
    (ODEIVP f)  -- ^ problem to solve
    ->
    (
        Maybe result
    ,
        (
            BisectionInfo solvingInfo (solvingInfo, Maybe (Imprecision (Domain f)))
        )
    )
solveODEIVPByBisectingT
        solver measureResultImprecision makeMakeInitValFnVec
            effDom splitImprovementThreshold minStepSize 
                odeivpG 
    =
    result
    where
    result = splitSolve odeivpG
    effAddDom = ArithInOut.fldEffortAdd sampleDom $ ArithInOut.rrEffortField sampleDom effDom
    effDivDomInt = 
        ArithInOut.mxfldEffortDiv sampleDom (1 :: Int) $ 
            ArithInOut.rrEffortIntMixedField sampleDom effDom
    sampleDom = odeivp_tStart odeivpG

--    effRefComp = ArithInOut.rrEffortRefComp sampleDom effDom
--    effMinmax = ArithInOut.rrEffortMinmaxInOut sampleDom effDom
--    effImpr = ArithInOut.rrEffortImprecision sampleDom effDom
--    sampleImpr = imprecisionOfEff effImpr sampleDom
--    effAddImpr = ArithInOut.fldEffortAdd sampleImpr $ ArithInOut.rrEffortImprecisionField sampleDom effDom
    
    splitSolve odeivp =
--        unsafePrint
--        (
--            "solveODEIVPByBisectingT: splitSolve: "
--            ++ "shouldRoundInwards = " ++ show shouldRoundInwards
--            ++ "tStart = " ++ show tStart
--            ++ "tEnd = " ++ show tEnd
--        ) $
        results
        where
        results
            | belowStepSize = directComputation
            | directComputationFailed = splitComputation
            | otherwise = 
                case maybeSplitImprovement of
                    Just improvementBy 
                        | (improvementBy >? splitImprovementThreshold) == Just True -> 
                            splitComputation
                    _ -> directComputation
        tStart = odeivp_tStart odeivp
        tEnd = odeivp_tEnd odeivp
        
        belowStepSize =
--            unsafePrintReturn ("belowStepSize = ") $
            let ?addInOutEffort = effAddDom in
            ((tEnd <-> tStart) >? minStepSize) /= Just True

        directComputation =
            case maybeDirectResult of
                Just resultOut -> (Just resultOut, BisectionNoSplit directInfo)
                _ -> (Nothing, BisectionNoSplit directInfo) 
        directInfo@(maybeDirectResult, _) = solver odeivp
        directComputationFailed =
            case maybeDirectResult of Just _ -> False; _ -> True
        
        splitOnceComputation = -- needed only to decide whether splitting is benefitial, the result is then discarded
            case solver odeivpL of
                (Just midValuesOut, _) ->
                    case solver odeivpR of
                        (Just endValuesOut, _) -> Just endValuesOut 
                        _ -> Nothing
                    where
                    midValues = midValuesOut
                    odeivpR =
                        odeivp
                        {
                            odeivp_tStart = tMid,
                            odeivp_t0End = tMid, -- exact initial time
                            odeivp_makeInitialValueFnVec =
                                makeMakeInitValFnVec midValues 
                        }
                _ -> Nothing
                
        splitComputation =
            (maybeState, BisectionSplit (directInfo, maybeSplitImprovement) infoL maybeInfoR)
            where
            (maybeMidState, infoL) =
                splitSolve odeivpL
            (maybeState, maybeInfoR) =
                case maybeMidState of
                    Just midState ->
                        case splitSolve odeivpR of
                            (maybeState2, infoR) -> (maybeState2, Just infoR)
                        where
                        odeivpR =
                            odeivp
                            {
                                odeivp_tStart = tMid,
                                odeivp_t0End = tMid, -- exact initial time
                                odeivp_makeInitialValueFnVec =
                                    makeMakeInitValFnVec  midState
                            }
                    Nothing -> (Nothing, Nothing)
        odeivpL =
            odeivp
            {
                odeivp_tEnd = tMid
            }
        tMid =
            getMidPoint effAddDom effDivDomInt tStart tEnd 
        
        maybeSplitImprovement =
            case (directComputation, splitOnceComputation) of
                ((Just directResult, _), Just splitOnceResult) -> 
                        measureImprovementVec directResult splitOnceResult
                _ -> Nothing

        measureImprovementVec res1 res2 =
            let ?addInOutEffort = effAddDom in
            Just $ imprecision1 <-> imprecision2
            where
            imprecision1 = measureResultImprecision res1
            imprecision2 = measureResultImprecision res2
--        measureImprovementVec vec1 vec2 = 
--            do
--            improvements <- sequence $ 
--                                map measureImprovement $ 
--                                    zip vec1 vec2
--            Just $ foldl1 (NumOrd.minOutEff effMinmax) improvements
--        measureImprovement (encl1, encl2) =
--            let ?addInOutEffort = effAddDom in
--            let ?pCompareEffort = effRefComp in
--            do
----            refines <- encl1 |<=? encl2
----            case refines of
----                True -> 
--                    Just $ (imprecisionOfEff effImpr encl1) <-> (imprecisionOfEff effImpr encl2)
----                False -> Nothing 
                
solveODEIVPByBisectingT0 ::
    (CanAddVariables f,
     CanEvaluate f,
     CanCompose f,
     HasProjections f,
     HasConstFns f,
     RefOrd.PartialComparison f,
     RoundedIntegration f,
     ArithInOut.RoundedAdd f,
     ArithInOut.RoundedMixedAdd f (Domain f),
     ArithInOut.RoundedReal (Domain f), 
     RefOrd.IntervalLike(Domain f),
     Domain f ~ Imprecision (Domain f),
     solvingInfoSub ~ ((Domain f, Maybe [Domain f]), solvingInfo),
     Show f, Show (Domain f))
    =>
    (ODEIVP f -> (Maybe [Domain f], solvingInfo)) -- ^ solver to use for segments  
    ->
    ArithInOut.RoundedRealEffortIndicator (Domain f) 
    ->
    Imprecision (Domain f) -- ^ splitting improvement threshold
    ->
    Domain f -- ^ minimum segment length  
    ->
    (ODEIVP f)  -- ^ problem to solve
    ->
    (
        Maybe [Domain f]
    , 
        BisectionInfo solvingInfoSub (solvingInfoSub, Maybe (Imprecision (Domain f)))
    )
solveODEIVPByBisectingT0
        solver
            effDom splitImprovementThreshold minStepSize 
                odeivpG 
    =
    splitSolve odeivpG
    where
    effAddDom = ArithInOut.fldEffortAdd sampleDom $ ArithInOut.rrEffortField sampleDom effDom
    effDivDomInt = 
        ArithInOut.mxfldEffortDiv sampleDom (1 :: Int) $ 
            ArithInOut.rrEffortIntMixedField sampleDom effDom
    effRefComp = ArithInOut.rrEffortRefComp sampleDom effDom
    sampleDom = odeivp_tStart odeivpG
    effMinmax = ArithInOut.rrEffortMinmaxInOut sampleDom effDom
    effJoinDom = ArithInOut.rrEffortJoinMeet sampleDom effDom
    
    effImpr = ArithInOut.rrEffortImprecision sampleDom effDom
--    sampleImpr = imprecisionOfEff effImpr sampleDom
--    effAddImpr = ArithInOut.fldEffortAdd sampleImpr $ ArithInOut.rrEffortImprecisionField sampleDom effDom
    
    splitSolve odeivp
        | belowStepSize = directComputation
        | directComputationFailed = splitComputation
        | otherwise = 
            case maybeSplitImprovement of
                Just improvementBy 
                    | (improvementBy >? splitImprovementThreshold) == Just True -> 
                        splitComputation
                _ -> directComputation
        where
        tStart = odeivp_tStart odeivp
        t0End = odeivp_t0End odeivp
        tEnd = odeivp_tEnd odeivp
        
        belowStepSize =
--            unsafePrintReturn ("belowStepSize = ") $
            let ?addInOutEffort = effAddDom in
            ((t0End <-> tStart) >? minStepSize) /= Just True

        directComputation =
            (maybeDirectResult, BisectionNoSplit ((tEnd, maybeDirectResult), directInfo))
        (maybeDirectResult, directInfo) = solver odeivp
        directComputationFailed =
            case maybeDirectResult of Just _ -> False; _ -> True
        
        splitOnceComputation = -- needed only to decide whether splitting is benefitial, the result is then discarded
            case solver odeivpL of
                (Just endValuesLOut, _) -> 
                    case solver odeivpR of
                        (Just endValuesROut, _) ->
                            Just endValuesOut
                            where
                            endValuesOut =
                                let ?joinmeetEffort = effJoinDom in
                                zipWith (</\>) endValuesLOut endValuesROut
                        _ -> Nothing
                    where
                    odeivpR =
                        odeivp
                        {
                            odeivp_tStart = t0Mid
                        }
                _ -> Nothing

        splitComputation =
            case splitSolve odeivpL of
                (Just endValuesLOut, infoL) -> 
                    case splitSolve odeivpR of
                        (Just endValuesROut, infoR) ->
                            (Just endValuesOut, BisectionSplit (((tEnd, maybeDirectResult), directInfo), maybeSplitImprovement) infoL (Just infoR))
                            where
                            endValuesOut =
                                let ?joinmeetEffort = effJoinDom in
                                zipWith (</\>) endValuesLOut endValuesROut
                        (Nothing, infoR) ->
                            (Nothing, BisectionSplit (((tEnd, maybeDirectResult), directInfo), maybeSplitImprovement) infoL (Just infoR))
                    where
                    odeivpR =
                        odeivp
                        {
                            odeivp_tStart = t0Mid 
                        }
                failedLeftComputation -> failedLeftComputation

        odeivpL =
            odeivp
            {
                odeivp_t0End = t0Mid
            }
        t0Mid =
            getMidPoint effAddDom effDivDomInt tStart t0End 
        
        maybeSplitImprovement =
            case (directComputation, splitOnceComputation) of
                ((Just directResult, _), Just splitOnceResult) ->
--            case (directComputation, splitComputation) of
--                ((Just (directResult, _), _), (Just (splitOnceResult, _), _)) ->
                    measureImprovementVec directResult splitOnceResult
                _ -> Nothing
        measureImprovementVec vec1 vec2 =
            do
            improvements <- sequence $ zipWith measureImprovement vec1 vec2
            Just $ foldl1 (NumOrd.minOutEff effMinmax) improvements
        measureImprovement encl1 encl2 =
            let ?addInOutEffort = effAddDom in
            let ?pCompareEffort = effRefComp in
            do
--            refines <- encl1 |<=? encl2
--            case refines of
--                True -> 
                    Just $ (imprecisionOfEff effImpr encl1) <-> (imprecisionOfEff effImpr encl2)
--                False -> Nothing 

data BisectionInfo segInfo splitReason
    = BisectionNoSplit segInfo
    | BisectionSplit splitReason (BisectionInfo segInfo splitReason) (Maybe (BisectionInfo segInfo splitReason))

showBisectionInfo :: 
    (String -> segInfo -> String) 
    -> 
    (String -> splitReason -> String) 
    -> 
    String -> BisectionInfo segInfo splitReason -> String
showBisectionInfo showSegInfo showSplitReason indentG bisectionInfoG =
    shLevel indentG bisectionInfoG
    where
    shLevel indent bisectionInfo =
        case bisectionInfo of
            BisectionNoSplit segInfo -> showSegInfo indent segInfo
            BisectionSplit reason infoL Nothing ->
                (showSplitReason indent reason)
                ++ "\n" ++
                (shLevel (indent ++ "| ") infoL)
            BisectionSplit reason infoL (Just infoR) ->
                (showSplitReason indent reason)
                ++ "\n" ++
                (shLevel (indent ++ "| ") infoL)
                ++ "\n" ++
                (shLevel (indent ++ "  ") infoR)
             
bisectionInfoCountLeafs ::
    BisectionInfo segInfo splitReason -> Int
bisectionInfoCountLeafs (BisectionNoSplit _) = 1
bisectionInfoCountLeafs (BisectionSplit _ left Nothing) =
    bisectionInfoCountLeafs left
bisectionInfoCountLeafs (BisectionSplit _ left (Just right)) =
    bisectionInfoCountLeafs left + bisectionInfoCountLeafs right
    
    
bisectionInfoGetLeafSegInfoSequence ::
    BisectionInfo segInfo splitReason -> [segInfo]
bisectionInfoGetLeafSegInfoSequence (BisectionNoSplit info) = [info]
bisectionInfoGetLeafSegInfoSequence (BisectionSplit _ left Nothing) =
    bisectionInfoGetLeafSegInfoSequence left
bisectionInfoGetLeafSegInfoSequence (BisectionSplit _ left (Just right)) =
    bisectionInfoGetLeafSegInfoSequence left
    ++
    bisectionInfoGetLeafSegInfoSequence right

checkConditionOnBisection ::
    (ArithInOut.RoundedReal dom,
     RefOrd.IntervalLike dom) 
    => 
    ArithInOut.RoundedRealEffortIndicator dom ->
    (segInfo -> Maybe Bool) {-^ the condition to check -} -> 
    BisectionInfo segInfo (segInfo, otherInfo) {-^ bisected function  -} -> 
    (dom, dom) {-^ the domain of the function encoded by the above bisection -} -> 
    dom -> 
    Maybe Bool
checkConditionOnBisection effDom condition bisectionInfo bisectionDom dom =
    aux bisectionDom bisectionInfo
    where
    aux _ (BisectionNoSplit info) = condition info
    aux (dL, dR) (BisectionSplit (info, _) left maybeRight) 
        | isJust resultUsingInfo = resultUsingInfo
        | domNotInR = auxLeft
        | domNotInL = auxRight
        | domInsideBothLR = 
            case auxLeft of
                Just _ -> auxLeft
                _ -> auxRight
        | otherwise = -- domSplitBetweenLR =
            case (auxLeft, auxRight) of
                (Just False, Just False) -> Just False
                (Just True , Just True ) -> Just True
                _ -> Nothing
        where
        resultUsingInfo = condition info
        domNotInL =
            let ?pCompareEffort = effComp in 
            (dM <? dom) == Just True
        domNotInR =
            let ?pCompareEffort = effComp in 
            (dom <? dM) == Just True
        domInsideBothLR = 
            let ?pCompareEffort = effComp in 
            (dom ==? dM) == Just True
        dM = 
            getMidPoint effAddDom effDivDomInt dL dR 
        auxLeft = aux (dL, dM) left
        auxRight = 
            case maybeRight of 
                Nothing -> Nothing
                Just right-> aux (dM, dR) right
    effComp = ArithInOut.rrEffortNumComp sampleDom effDom
--    effJoinMeet = ArithInOut.rrEffortJoinMeet sampleDom effDom
    effAddDom = ArithInOut.fldEffortAdd sampleDom $ ArithInOut.rrEffortField sampleDom effDom
    effDivDomInt = 
        ArithInOut.mxfldEffortDiv sampleDom (1 :: Int) $ 
            ArithInOut.rrEffortIntMixedField sampleDom effDom
    sampleDom = dom

evalFnOnBisection ::
    (ArithInOut.RoundedReal dom,
     RefOrd.IntervalLike dom) 
    => 
    ArithInOut.RoundedRealEffortIndicator dom ->
    (segInfo -> a) {-^ the evaluation function -} -> 
    BisectionInfo segInfo otherInfo {-^ bisected function  -} -> 
    (dom, dom) {-^ the domain of the function encoded by the above bisection -} -> 
    dom {-^ @dom@ - domain to evaluate the function on -} -> 
    [[a]] {-^ evaluation on various sub-segments of @dom@, possibly in multiple ways -}
evalFnOnBisection effDom evalFn bisectionInfo bisectionDom domG =
    aux bisectionDom bisectionInfo domG
    where
    aux _ (BisectionNoSplit info) _ = [[evalFn info]]
    aux (dL, dR) (BisectionSplit _ left maybeRight) dom 
        | domNotInR = auxLeft
        | domNotInL = auxRight
        | domInsideBothLR =
            zipWith (++) auxLeft auxRight 
        | otherwise = -- domSplitBetweenLR =
            auxLeft ++ auxRight
        where
        domNotInL =
            let ?pCompareEffort = effComp in 
            (dM <? dom) == Just True
        domNotInR =
            let ?pCompareEffort = effComp in 
            (dom <? dM) == Just True
        domInsideBothLR = 
            let ?pCompareEffort = effComp in 
            (dom ==? dM) == Just True
        dM = 
            getMidPoint effAddDom effDivDomInt dL dR 
        auxLeft = aux (dL, dM) left domL
        auxRight = 
            case maybeRight of 
                Nothing -> []
                Just right-> aux (dM, dR) right domR
        domL = 
            let ?joinmeetEffort = effJoinMeet in
            dom <\/> (dL </\> dM)
        domR =
            let ?joinmeetEffort = effJoinMeet in
            dom <\/> (dM </\> dR)
    effComp = ArithInOut.rrEffortNumComp sampleDom effDom
    effJoinMeet = ArithInOut.rrEffortJoinMeet sampleDom effDom
    effAddDom = ArithInOut.fldEffortAdd sampleDom $ ArithInOut.rrEffortField sampleDom effDom
    effDivDomInt = 
        ArithInOut.mxfldEffortDiv sampleDom (1 :: Int) $ 
            ArithInOut.rrEffortIntMixedField sampleDom effDom
    sampleDom = domG
    

getMidPoint :: 
    (RefOrd.IntervalLike dom, 
     ArithInOut.RoundedAdd dom,
     ArithInOut.RoundedMixedDivide dom Int) 
    =>
    ArithInOut.AddEffortIndicator dom 
    -> 
    ArithInOut.MixedDivEffortIndicator dom Int 
    -> 
    dom -> dom -> dom
getMidPoint effAddDom effDivDomInt l r =             
    let ?addInOutEffort = effAddDom in
    let ?mixedDivInOutEffort = effDivDomInt in
    fst $ RefOrd.getEndpointsOutWithDefaultEffort $
    (l <+> r) </>| (2 :: Int)
        