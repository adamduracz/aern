{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-|
    Module      :  Numeric.AERN.IVP.Solver.Events.SplitNearEvents
    Description :  hybrid system simulation  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Hybrid system simulation with splitting based on event localisation.
-}

module Numeric.AERN.IVP.Solver.Events.SplitNearEvents
(
    solveHybridIVP_UsingPicardAndEventTree_SplitNearEvents
)
where

import Numeric.AERN.IVP.Solver.Events.Locate
import Numeric.AERN.IVP.Solver.Events.Aggregate
import Numeric.AERN.IVP.Solver.Picard.UncertainValue

import Numeric.AERN.IVP.Specification.Hybrid
import Numeric.AERN.IVP.Specification.ODE
import Numeric.AERN.IVP.Solver.Bisection

import Numeric.AERN.RmToRn.Domain
import Numeric.AERN.RmToRn.New
import Numeric.AERN.RmToRn.Evaluation
import Numeric.AERN.RmToRn.Integration
import Numeric.AERN.RmToRn.Differentiation

import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsImplicitEffort
import Numeric.AERN.RealArithmetic.Measures
import Numeric.AERN.RealArithmetic.ExactOps

import qualified Numeric.AERN.RealArithmetic.NumericOrderRounding as ArithUpDn

import qualified Numeric.AERN.NumericOrder as NumOrd
import Numeric.AERN.NumericOrder.OpsDefaultEffort

import qualified Numeric.AERN.RefinementOrder as RefOrd
import Numeric.AERN.RefinementOrder.OpsImplicitEffort

import Numeric.AERN.Basics.Consistency

import qualified Data.Map as Map
--import qualified Data.Set as Set
import qualified Data.List as List
import Data.Maybe (catMaybes)

import Numeric.AERN.Misc.Debug
_ = unsafePrint

solveHybridIVP_UsingPicardAndEventTree_SplitNearEvents ::
    (CanAddVariables f,
     CanRenameVariables f,
     CanEvaluate f,
     CanCompose f,
     CanChangeSizeLimits f,
     CanPartiallyEvaluate f,
     HasProjections f,
     HasConstFns f,
     RefOrd.IntervalLike f,
     HasAntiConsistency f,
     NumOrd.RefinementRoundedLattice f,
     RefOrd.PartialComparison f,
     RoundedIntegration f,
     RoundedFakeDerivative f,
     ArithInOut.RoundedAdd f,
     ArithInOut.RoundedSubtr f,
     ArithInOut.RoundedMultiply f,
     ArithInOut.RoundedMixedDivide f Int,
     ArithInOut.RoundedMixedAdd f (Domain f),
     ArithInOut.RoundedMixedMultiply f (Domain f),
     ArithUpDn.RoundedAbs f,
     NumOrd.RoundedLattice f,
     ArithInOut.RoundedReal (Domain f), 
     RefOrd.IntervalLike (Domain f),
     HasAntiConsistency (Domain f),
     Domain f ~ Imprecision (Domain f),
     solvingInfoODESegment ~ (Maybe [f], (Domain f, Maybe [Domain f])),
     solvingInfoODE ~ BisectionInfo solvingInfoODESegment (solvingInfoODESegment, Maybe (Domain f)),
     solvingInfoEvents ~ (Domain f, Maybe (HybridSystemUncertainState (Domain f)), [(HybSysMode, EventInfo f)]),
     Show f, Show (Domain f), Show (Var f), Eq (Var f))
    =>
    SizeLimits f {-^ size limits for all function -} ->
    SizeLimitsChangeEffort f ->
    PartialEvaluationEffortIndicator f ->
    CompositionEffortIndicator f ->
    EvaluationEffortIndicator f ->
    IntegrationEffortIndicator f ->
    FakeDerivativeEffortIndicator f ->
    RefOrd.PartialCompareEffortIndicator f ->
    ArithInOut.AddEffortIndicator f ->
    ArithInOut.MultEffortIndicator f ->
    ArithUpDn.AbsEffortIndicator f ->
    NumOrd.MinmaxEffortIndicator f ->
    ArithInOut.MixedDivEffortIndicator f Int ->
    ArithInOut.MixedAddEffortIndicator f (Domain f) ->
    ArithInOut.MixedMultEffortIndicator f (Domain f) ->
    ArithInOut.RoundedRealEffortIndicator (Domain f) ->
    Domain f {-^ initial widening @delta@ -}  ->
    Int {-^ @m@ -} -> 
    Var f {-^ @t0@ - the initial time variable -} ->
    Domain f {-^ min step size @s@ -} -> 
    Domain f {-^ max step size @s@ -} -> 
    Imprecision (Domain f) {-^ split improvement threshold @eps@ -} ->
    HybridIVP f
    ->
    (
        Maybe (HybridSystemUncertainState (Domain f))
    ,
        [(
            Domain f
            -- start and end time of this segment (including the event resolution sub-segment)  
         ,
            Maybe (HybridSystemUncertainState (Domain f))
         ,
            Map.Map HybSysMode 
                (
                    solvingInfoODE,
                    Maybe (HybridSystemUncertainState (Domain f)),
                    Maybe solvingInfoEvents
                )
         )
        ]
    )
solveHybridIVP_UsingPicardAndEventTree_SplitNearEvents
        sizeLimits effSizeLims effPEval effCompose effEval effInteg effDeriv effInclFn 
            effAddFn effMultFn effAbsFn effMinmaxFn 
            effDivFnInt effAddFnDom effMultFnDom effDom
            delta m t0Var minStepSize maxStepSize splitImprovementThreshold
                hybivpG
    = 
    solve hybivpG
    where
    solve hybivp =
        solveHybridIVP_SplitNearEvents
            solveHybridNoSplitting
            solveODEWithSplitting
                effEval effDom 
                    minStepSize maxStepSize
                        hybivp

    solveODEWithSplitting =
        solveODEIVPUncertainValueExactTime_UsingPicard_Bisect
            shouldWrap shouldShrinkWrap
                sizeLimits effSizeLims effCompose effEval effInteg effDeriv effInclFn 
                effAddFn effMultFn effAbsFn effMinmaxFn 
                effDivFnInt effAddFnDom effMultFnDom effDom
                    delta m minStepSize splitImprovementThreshold
        where
        shouldWrap = True
        shouldShrinkWrap = False

    solveHybridNoSplitting hybivp =
        (maybeFinalStateWithInvariants, (tEnd, maybeFinalStateWithInvariants, modeEventInfoList))
        where
        tEnd = hybivp_tEnd hybivp
        maybeFinalStateWithInvariants
            = fmap filterInvariants maybeFinalState
            where
            filterInvariants st =
                Map.mapWithKey filterInvariantsVec st
                where
                filterInvariantsVec mode vec =
                    invariant vec
                    where
                    Just invariant =
                        Map.lookup mode modeInvariants
        modeInvariants = hybsys_modeInvariants $ hybivp_system hybivp
        (maybeFinalState, modeEventInfoList) = 
            solveHybridIVP_UsingPicardAndEventTree
                sizeLimits effPEval effCompose effEval effInteg effInclFn effAddFn effMultFn effAddFnDom effDom
                     20
                        delta m
                            t0Var
                                hybivp

solveHybridIVP_SplitNearEvents ::
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
     Show f, Show (Domain f), Show (Var f),
     solvingInfoODESegment ~ (Maybe [f], solvingInfoODESegmentOther),
     solvingInfoODE ~ BisectionInfo solvingInfoODESegment (solvingInfoODESegment, prec)
    )
    =>
    (HybridIVP f -> (Maybe (HybridSystemUncertainState (Domain f)), solvingInfoEvents))
        -- ^ solver to use on small segments that may contain events  
    ->
    (ODEIVP f -> (Maybe [Domain f], solvingInfoODE))
        -- ^ solver to use on large segments before event localisation  
    ->
    EvaluationEffortIndicator f
    -> 
    ArithInOut.RoundedRealEffortIndicator (Domain f) 
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
        [(
            Domain f 
            -- ^ end time of this segment (including the event resolution sub-segment)  
         ,
            Maybe (HybridSystemUncertainState (Domain f))
            -- ^ state at the end time of this segment (if simulation has not failed)
         ,
            Map.Map HybSysMode 
                ( 
                 solvingInfoODE, 
                 Maybe (HybridSystemUncertainState (Domain f)),
                 Maybe solvingInfoEvents
                )
            -- ^ solving information (typically including an enclosure of all solutions)
         )
        ]
    )
solveHybridIVP_SplitNearEvents
        solveHybridNoSplitting
        solveODEWithSplitting
            effEval effDom 
                minStepSize maxStepSize
                    (hybivpG :: HybridIVP f)
    =
    (finalState, segments)
    {-
        overview:
        
        (1) apply solveODEWithSplitting over T for each initial mode/value combination DONE
        (2) for each computed enclosure, locate the first event on T, obtaining:
            (maybe) interval T_mode \subseteq T where first event must occur + set of possible event types
        (3) compute (maybe) T_e as follows: the left endpoint is the leftmost point of all T_mode,
            the right endpoint is the rightmost point of all T_mode that transitively overlap with the
            left-most T_mode. 
        (4)
            (a) if we have T_ev \subseteq T, set t_R = \rightendpoint{T_ev}
                and apply solveHybridNoSplitting on T_e to compute value A_R at t_R
            (b) if we do not have any event, return [segment info]
        (5) if t_R < \rightendpoint{T}, 
            recursively apply this computation on the interval [t_R, \rightendpoint{T}]
    -}
    where
    (_, finalState, _) = last segments
    segments = splitSolve hybivpG
    splitSolve hybivp =
        (tEventR, stateAtTEventR, simulationInfoModeMap) : rest
        where
        effJoinMeet = ArithInOut.rrEffortJoinMeet sampleD effDom
        effMinmax = ArithInOut.rrEffortMinmaxInOut sampleD effDom
        effAdd = ArithInOut.fldEffortAdd sampleD $ ArithInOut.rrEffortField sampleD effDom
        sampleD = tEventR
        
        rest =
            undefined
            -- TODO: if tEventR < tEnd, construct new hybivp, mainly its initial uncertain state
        stateAtTEventR =
            case states of
                [] -> Nothing
                _ -> Just $ foldl1 (mergeHybridStates effJoinMeet) states   
            where
            states = catMaybes $ map getState $ Map.elems simulationInfoModeMap
            getState (_, state, _) = state
        simulationInfoModeMap = Map.mapWithKey processEvents firstDipModeMap
        processEvents mode (noEventsSolution, locateDipResult) =
            case locateDipResult of 
                LDResNone ->
                    (noEventsSolution, noEventsStateAt tEventR, Nothing)
                LDResSome _certainty (tEventL, _) _possibleEvents
                    | ((tEventR <=? tEventL) == Just True) 
                        -- an event was located but it could not happen before tEventR  
                        -> (noEventsSolution, noEventsStateAt tEventR, Nothing)
                    | otherwise
                        -- call solveHybridIVP_UsingPicardAndEventTree over (tEventL, tEventR)
                        ->
                        (noEventsSolution, stateAfterEvents, maybeSolvingInfo)
                    where
                    (stateAfterEvents, maybeSolvingInfo) = solveEvents tEventL
            where
            noEventsStateAt :: Domain f -> Maybe (HybridSystemUncertainState (Domain f))
            noEventsStateAt t =
                case valuesVariants of
                    [] -> Nothing
                    _ -> Just $ Map.singleton mode values
                where
                values = 
                    let ?joinmeetEffort = effJoinMeet in
                    foldl1 (zipWith (<\/>)) valuesVariants
                valuesVariants = catMaybes valuesMaybeVariants
                [valuesMaybeVariants] = 
                    evalFnOnBisection effDom evalFnsAtTEventsR noEventsSolution (tStart, tEnd) t
                evalFnsAtTEventsR (Just fns, _) = Just $ map evalFnAtTEventsR fns
                evalFnsAtTEventsR _ = Nothing
                evalFnAtTEventsR fn = evalAtPointOutEff effEval boxD fn
                boxD = fromList [(tVar, t)]
            solveEvents tEventL =
                case noEventsStateAt tEventL of
                    Nothing -> (Nothing, Nothing)
                    Just midState -> solveEventsFromState midState
                where
                solveEventsFromState midState =
                    (finalState2, Just solvingInfo)
                    where
                    (finalState2, solvingInfo) = solveHybridNoSplitting (hybivpEventRegion midState) 
                hybivpEventRegion midState =
                    hybivp
                    {
                        hybivp_tStart = tEventL,
                        hybivp_tEnd = tEventR,
                        hybivp_initialStateEnclosure = midState
                    }
        tEventR :: Domain f
        tEventR =
            keepAddingIntersectingDomsAndReturnR leftmostDomR doms
            -- compute a intersection-transitive-closure of all doms in dipInfos starting from leftmostDom  
            where
            keepAddingIntersectingDomsAndReturnR dR domsLeft = 
                case intersectingDoms of
                    [] -> dR
                    _ -> keepAddingIntersectingDomsAndReturnR newR nonintersectingDoms
                where
                (intersectingDoms, nonintersectingDoms) =
                    List.partition intersectsDom domsLeft
                    where
                    intersectsDom (dL, _) = (dL <? dR) /= Just False
                newR = foldl pickTheRightOne dR (map snd intersectingDoms)
                    where
                    pickTheRightOne d1 d2
                        | (d1 >? d2) == Just True = d1
                        | otherwise = d2
            (_, leftmostDomR) =
                foldr1 pickTheLeftOne ((tEnd, tEnd) : doms)
                where
                pickTheLeftOne d1@(d1L,_) d2@(d2L, _) 
                    | (d1L <? d2L) == Just True = d1
                    | otherwise = d2
            doms =
                map getLDResDom $ filter (not . isLDResNone) $ map snd $ Map.elems firstDipModeMap
            
--        firstDipModeMap ::
--            (
--             solvingInfoODESegment ~ (Maybe [f], solvingInfoODESegmentOther),
--             solvingInfoODE ~ (BisectionInfo solvingInfoODESegment (solvingInfoODESegment, prec))
--            )
--            =>
--            Map.Map HybSysMode (solvingInfoODE, LocateDipResult (Domain f) HybSysEventKind)
        firstDipModeMap =
            Map.mapWithKey locate noEventsSolutionModeMap
            where
            locate mode noEventsSolution@(bisectionInfo) =
                (noEventsSolution, dipInformation)
                where
                dipInformation =
                    locateFirstDipAmongMultipleFns
                        minStepSize
                        eventDetectionInfoMap 
                        (tStart, tEnd)
                eventDetectionInfoMap =
                    Map.map makeDetectionInfo eventSpecMap
                eventSpecMap = hybsys_eventSpecification hybsys mode
                makeDetectionInfo (_, makeDipFn, otherCond, _) =
                    (otherConditionOnDom, dipFnPositiveOnDom, dipFnNegativeOnDom, dipFnEnclosesZeroOnDom)
                    where                    
                    otherConditionOnDom =
                        checkConditionOnBisectedFunction id otherCond
                    dipFnNegativeOnDom =
                        checkConditionOnBisectedFunction makeDipFnL (\[x] -> x <? (zero x))
                    dipFnPositiveOnDom =
                        checkConditionOnBisectedFunction makeDipFnL (\[x] -> (zero x) <? x)
                    dipFnEnclosesZeroOnDom =
                        checkConditionOnBisectedFunction makeDipFnL enclosesZero
                        where
                        enclosesZero [x] =
                            case (xL <=? z, z <=? xR) of
                                (Just True, Just True) -> Just True
                                _ -> Nothing
                            where
                            (xL, xR) = RefOrd.getEndpointsOutWithDefaultEffort x
                            z = zero x
                    makeDipFnL :: [f] -> [f]
                    makeDipFnL fns = [makeDipFn fns]
                    checkConditionOnBisectedFunction functionCalculation valueCondition dom =
                        checkConditionOnBisection effDom condition bisectionInfo (tStart, tEnd) dom
                        where
                        condition (Nothing, _) = Nothing
                        condition (Just fns, _) = 
                            valueCondition $
                                map eval $ 
                                    functionCalculation fns
                        eval fn = evalAtPointOutEff effEval boxD fn
                        boxD = fromList [(tVar, dom)] 
--        noEventsSolutionModeMap ::
--            Map.Map HybSysMode (BisectionInfo solvingInfoODESegment (solvingInfoODESegment, prec))
        noEventsSolutionModeMap =
            Map.mapWithKey solve initialStateModeMap
            where
            solve mode initialValues =
                snd $ solveODEWithSplitting (odeivp mode initialValues)
        odeivp :: HybSysMode -> [Domain f] -> ODEIVP f
        odeivp mode initialValues =
            ODEIVP
            {
                odeivp_description = "ODE for " ++ show mode,
                odeivp_field = field,
                odeivp_componentNames = componentNames,
                odeivp_tVar = tVar,
                odeivp_tStart = tStart,
                odeivp_tEnd = tStepEnd,
                odeivp_makeInitialValueFnVec = makeInitValueFnVec,
                odeivp_t0End = tStart,
                odeivp_maybeExactValuesAtTEnd = Nothing
            }
            where
            makeInitValueFnVec = makeFnVecFromInitialValues componentNames initialValues
            Just field = Map.lookup mode modeFields
        
        tVar = hybivp_tVar hybivp
        tStart = hybivp_tStart hybivp
        tEnd = hybivp_tEnd hybivp
        tStepEnd = -- min(tEnd, tStart + maxStepSize)
            NumOrd.minOutEff effMinmax tEnd tStartPlusMaxStep
            where
            (tStartPlusMaxStep, _) =
                let ?addInOutEffort = effAdd in
                RefOrd.getEndpointsOutWithDefaultEffort $ 
                tStart <+> maxStepSize
--        tDom = RefOrd.fromEndpointsOutWithDefaultEffort (tStart, tEnd)
        initialStateModeMap = hybivp_initialStateEnclosure hybivp
        hybsys = hybivp_system hybivp
        componentNames = hybsys_componentNames hybsys
        modeFields = hybsys_modeFields hybsys
        
        
----        unsafePrint
----        (
----            "solveHybridIVPByBisectingT: splitSolve: "
----            ++ "tStart = " ++ show tStart
----            ++ "tEnd = " ++ show tEnd
----        ) $
--        result2
--        where
--        result2
--            | belowStepSize = directComputation
--            | aboveMaxStepSize = splitComputation
--            | directComputationFailed = splitComputation
--            | otherwise = 
--                case maybeSplitImprovement of
--                    Just improvementBy 
--                        | (improvementBy >? splitImprovementThreshold) /= Just True -> 
--                            directComputation -- split once computations succeeded but brought no noticeable improvement
--                    _
--                        | splitComputationFailed -> directComputation
--                        | otherwise -> splitComputation -- splitting either brought noticeable improvement or some computation failed 
--        tStart = hybivp_tStart hybivp
--        tEnd = hybivp_tEnd hybivp
--        
--        belowStepSize =
--            let ?addInOutEffort = effAddDom in
--            ((tEnd <-> tStart) >? minStepSize) /= Just True
--        aboveMaxStepSize =
--            let ?addInOutEffort = effAddDom in
--            ((tEnd <-> tStart) <? maxStepSize) /= Just True
--
--        directComputation =
----            unsafePrint
----            (
----                "solveHybridIVPByBisectingT: completed time " ++ show tEnd
----            ) $
--            case maybeDirectResult of
--                Just resultOut 
--                    | otherwise -> (Just resultOut, BisectionNoSplit directInfo)
--                _ -> (Nothing, BisectionNoSplit directInfo) 
--        (maybeDirectResult, directInfo) = solver depth hybivp
--        directComputationFailed =
--            case maybeDirectResult of Just _ -> False; _ -> True
--        
--        splitOnceComputation = -- needed only to decide whether splitting is benefitial, the result is then discarded
--            case solver (depth + 1) hybivpL of
--                (Just midState, _) ->
--                    case solver (depth + 1) hybivpR of
--                        (Just endStateOut, _) -> Just endStateOut 
--                        _ -> Nothing
--                    where
--                    hybivpR =
--                        hybivp
--                        {
--                            hybivp_tStart = tMid,
--                            hybivp_initialStateEnclosure = midState
--                        }
--                _ -> Nothing
--                
--        (splitComputation, splitComputationFailed) =
--            (
--                (maybeState, BisectionSplit (directInfo, maybeSplitImprovement) infoL maybeInfoR)
--            , 
--                case maybeState of Just _ -> False; _ -> True
--            )
--            where
--            (maybeMidState, infoL) =
--                splitSolve (depth + 1) hybivpL
--            (maybeState, maybeInfoR) =
--                case maybeMidState of
--                    Just midState ->
--                        case splitSolve (depth + 1) hybivpR of
--                            (maybeState2, infoR) -> (maybeState2, Just infoR)
--                        where
--                        hybivpR =
--                            hybivp
--                            {
--                                hybivp_tStart = tMid,
--                                hybivp_initialStateEnclosure = midState
--                            }
--                    Nothing -> (Nothing, Nothing)
--        hybivpL =
--            hybivp
--            {
--                hybivp_tEnd = tMid
--            }
--        tMid = 
--            let ?addInOutEffort = effAddDom in
--            let ?mixedDivInOutEffort = effDivDomInt in
--            (tStart <+> tEnd) </>| (2 :: Int)
--        
--        maybeSplitImprovement =
--            case (maybeDirectResult, splitOnceComputation) of
--                (Just directResult, Just splitOnceResult) -> 
--                    Just $ measureImprovementState sampleDom effDom directResult splitOnceResult
--                _ -> Nothing
--
--    effAddDom = ArithInOut.fldEffortAdd sampleDom $ ArithInOut.rrEffortField sampleDom effDom
--    effDivDomInt = 
--        ArithInOut.mxfldEffortDiv sampleDom (1 :: Int) $ 
--            ArithInOut.rrEffortIntMixedField sampleDom effDom
----    effRefComp = ArithInOut.rrEffortRefComp sampleDom effDom
--    sampleDom = hybivp_tStart hybivpG
----    effMinmax = ArithInOut.rrEffortMinmaxInOut sampleDom effDom
--    
----    effImpr = ArithInOut.rrEffortImprecision sampleDom effDom
----    sampleImpr = imprecisionOfEff effImpr sampleDom
----    effAddImpr = ArithInOut.fldEffortAdd sampleImpr $ ArithInOut.rrEffortImprecisionField sampleDom effDom
                                