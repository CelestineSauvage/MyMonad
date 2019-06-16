Require Import Program List Arith Coq.Logic.Classical_Prop Omega Bool Coq.Arith.PeanoNat Coq.Init.Nat.

Set Implicit Arguments.

Import Notations.

Section monads.

Local Notation "f ∘ g" := (fun x => f (g x)) (at level 40, left associativity).

(* State Monad *)

Variable St : Type.

Definition State (A : Type) := St -> A * St.

(* Arguments State [ A ]. *)

(* forall {A}, A -> m A; *)
Definition state_pure A (a : A) : State A := 
  fun s => (a,s).

(* state_bind = 
fun (A : Type) (st_a : State A) (B : Type) (f : A -> State B) (s : S) => let (a, s0) := st_a s in f a s0
     : forall A : Type, State A -> forall B : Type, (A -> State B) -> S -> B * S *)
Definition state_bind {A B} (st_a : State A) (f : A -> State B)  : State B :=
  fun s => let (a, s0) := st_a s in f a s0.


Lemma state_bind_right_unit : 
  forall (A : Type) (a: State A), a = state_bind a (@ state_pure A).
  Proof.
  intros.
  unfold state_bind.
  apply functional_extensionality.
  intros.
  destruct (a x).
  reflexivity.
  Qed.

Lemma state_bind_left_unit :
   forall A (a: A) B (f: A -> State B),
             f a = state_bind (state_pure a) f.
   Proof.
   auto.
   Qed.

Lemma state_bind_associativity :
  forall A (ma: State A) B f C (g: B -> State C),
                 state_bind ma (fun x => state_bind (f x) g) = state_bind (state_bind ma f) g.
  Proof.
  intros.
  unfold state_bind.
  apply functional_extensionality.
  intros.
  destruct (ma x).
  reflexivity.
  Qed.

Definition put (x : St) : State () :=
  fun _ => (tt,x).

Definition get : State St :=
  fun x => (x,x).

Definition runState  {A} (op : State A) : St -> A * St := op.
Definition evalState {A} (op : State A) : St -> A := fst ∘ op.
Definition execState {A} (op : State A) : St -> St := snd ∘ op.

Notation "m1 ;; m2" := (state_bind m1 (fun _ => m2))  (at level 60, right associativity) : monad_scope.
Notation "'perf' x '<-' m ';' e" := (state_bind m (fun x => e))
  (at level 60, x ident, m at level 200, e at level 60) : monad_scope.

Open Scope monad_scope.

(* modify = 
fun (S : Type) (f : S -> S) => perf s <- getS (S:=S); putS (f s)
     : forall S : Type, (S -> S) -> State S () *)
Definition modify (f : St -> St) : State () :=
  perf s <- get; put (f s).

Definition Assertion := St -> Prop.

Definition hoareTripleS {A} (P : St -> Prop) (m : State A) (Q : A -> St -> Prop) : Prop :=
  forall (s : St), P s -> let (a, s') := m s in Q a s'.

Notation "{{ P }} m {{ Q }}" := (hoareTripleS P m Q)
  (at level 90, format "'[' '[' {{  P  }}  ']' '/  ' '[' m ']' '['  {{  Q  }} ']' ']'") : monad_scope.

Lemma ret  (A : Type) (a : A) (P : A -> Assertion) : {{ P a }} state_pure a {{ P }}.
Proof.
intros s H; trivial.
Qed.

(* Triplet de hoare sur la séquence *)
Lemma bind  (A B : Type) (m : State A) (f : A -> State B) (P : Assertion)( Q : A -> Assertion) (R : B -> Assertion) :
  (forall a, {{ Q a }} f a {{ R }}) -> {{ P }} m {{ Q }} -> {{ P }} perf x <- m ; f x {{ R }}.
Proof. 
intros H1 H2 s H3.
unfold state_bind.
case_eq (m s).
intros a s' H4.
apply H2 in H3.
rewrite H4 in H3.
apply H1.
apply H3.
Qed.

Definition wp {A : Type} (P : A -> St -> Prop) (m : State A) :=
  fun s => let (a,s') := m s in P a s'.

Lemma wpIsPrecondition {A : Type} (P : A -> St -> Prop) (m : State A) :
  {{ wp P m }} m {{ P }}.
  Proof.
  unfold wp.
  congruence.
  Qed.

Lemma wpIsWeakestPrecondition
  (A : Type) (P : A -> St -> Prop) (Q : St -> Prop) (m : State A) :
  {{ Q }} m {{ P }} -> forall s, Q s -> (wp P m) s.
  Proof.
  trivial.
  Qed.

Lemma assoc (A B C : Type)(m : State A)(f : A -> State B)(g : B -> State C) :
  perf y <-
    perf x <- m ;
    f x ;
  g y =
  perf x <- m ;
  perf y <- f x ;
  g y.
  Proof.
  extensionality s; unfold state_bind; case (m s); trivial; tauto.
  Qed.

Lemma l_put (s : St) (P : unit -> Assertion) : {{ fun _ => P tt s }} put s {{ P }}.
Proof.
intros s0 H;trivial.
Qed.

Lemma l_get (P : St -> Assertion) : {{ fun s => P s s }} get {{ P }}.
Proof.
intros s H; trivial.
Qed.

Lemma sequence_rule (A B : Type) (m : State A) (f : A -> State B) (P : Assertion)( Q : A -> Assertion) (R : B -> Assertion) :
  {{ P }} m {{ Q }} -> (forall a, {{ Q a }} f a {{ R }}) -> {{ P }} perf x <- m ; f x {{ R }}.
Proof.
intros; eapply bind ; eassumption.
Qed.

Lemma weaken (A : Type) (m : State A) (P Q : Assertion) (R : A -> Assertion) :
  {{ Q }} m {{ R }} -> (forall s, P s -> Q s) -> {{ P }} m {{ R }}.
Proof.
intros H1 H2 s H3.
apply H2 in H3. 
apply H1 in H3.
assumption. 
Qed.

Lemma strengthen (A : Type) (m : State A) (P: Assertion) (Q R: A -> Assertion) :
  {{ P }} m {{ R }} -> (forall s a, R a s -> Q a s) -> {{ P }} m {{ Q }}.
Proof.
intros H1 H2 s H3.
apply H1 in H3.
Admitted.


Lemma l_modify f (P : () -> Assertion) : {{ fun s => P tt (f s) }} modify f {{ P }}.
Proof.
unfold modify.
eapply bind.
intros.
eapply l_put.
simpl.
eapply weaken.
eapply l_get.
intros. simpl.
assumption.
Qed.

Definition state_liftM {A B} (f : A -> B) (ma : State A) : State B :=
  state_bind ma (fun a => state_pure (f a)).

Inductive Action (A : Type) : Type :=
  | Break : Action A
  | Atom : A -> Action A.

Lemma act_ret  (A : Type) (a : A) (P : Assertion) : {{P}} state_pure (Atom a) 
{{fun (_ : Action A) =>  P }}.
Proof.
intros s H; trivial.
Qed.

(* Lemma ret_tt (P : () -> Assertion) : {{ P tt }} state_pure tt {{ P }}.
Proof.
intros s H; trivial.
Qed. *)

Arguments Atom [A] _.
Arguments Break [A].

Definition LoopT a : Type := State (Action a).

Definition runLoopT {A} (loop : LoopT A) : State (Action A) :=
  loop.

Definition loopT_pure {A} (a : A) : LoopT A :=
  (state_pure (Atom a)).

Definition loopT_bind  {A} (x : LoopT A) {B} (k : A -> LoopT B) : LoopT B :=
    perf o <- runLoopT x;
    match o with 
      | Break => state_pure Break
      | Atom y => runLoopT (k y)
    end.

Definition loopT_liftT {A} (a : State A) : LoopT A :=
  state_liftM (@Atom A) a.

Definition break {A} : LoopT A :=
  state_pure Break.

Fixpoint foreachT (it min : nat) (body : nat -> LoopT ()) : State () :=
  if (it <=? min) then state_pure tt
  else match it with
        | S it' => perf out <- runLoopT (body it');
                                match out with
                                  | Break => state_pure tt
                                  | _ => foreachT it' min body
                                end
        | 0 => state_pure tt
       end.

Lemma foreach_rule (min max : nat) (P : St -> Prop) (body : nat -> State ())
  : (forall (it : nat), {{fun s => P s /\ (min <= it < max)}} body it {{fun _ => P}}) -> 
    {{P}} foreachT max min (fun it0 => loopT_liftT (body it0)) {{fun _ => P}}.
  Proof.
  intros H.
  induction max.
  + intros st HP. simpl. auto.
  + unfold foreachT.
    case_eq (S max <=? min);intros Hm.
    - intros s HP. trivial.
    - eapply sequence_rule .
      unfold runLoopT.
      unfold loopT_liftT.
      unfold state_liftM.
      eapply sequence_rule.
      * unfold hoareTripleS in H.
        intros st H2.
        eapply H;split;auto.
        split;auto.
        apply Nat.leb_gt in Hm.
        omega.
      * intros [].
        apply act_ret.
    * intros []. intros s HP. trivial.
      apply IHmax.
         ++ intros it s'.
            intros [H1 [H2 H3]].
            apply H.
            split;auto.
     Qed.

(* 
Lemma foreachT_rule2 (min max : nat) (P : nat -> St -> Prop) (body : nat -> State ())
  : min <= max -> (forall (it : nat), {{fun s => (min <= it < max) -> P it s }} body it {{fun _ => P it}}) -> 
    {{P max}} foreachT max min (fun it0 => loopT_liftT (body it0)) {{fun _ => P min}}.
    Proof.
    intros Hleq H.
    unfold foreachT.
    induction max.
    + assert (min = 0) by omega.
      replace min with 0.
      intros s Hs.
      simpl.
      auto.
    + case_eq (S max <=? min);intros Hm.
      - intros s HP.
        simpl.
        rewrite Nat.leb_le in Hm.
        assert (S max = min) by omega.
        rewrite H0 in HP.
        auto.
      - eapply sequence_rule .
        unfold runLoopT.
        unfold loopT_liftT.
        unfold state_liftM.
        eapply sequence_rule.
        * unfold hoareTripleS in H.
          intros st H2.
          eapply H;split. 
          generalize (H max).
          intros.
          split. auto.
          apply Nat.leb_gt in Hm.
          apply Nat.lt_le_incl.
          auto.
        * intros [].
          apply act_ret.
      * intros []. intros s HP. trivial.
        apply IHmax.
           ++ intros it s'.
              intros [H1 [H2 H3]].
              apply H.
              split;auto.
       Qed. *)

Fixpoint foreach2' (vals : list nat) (body : nat -> LoopT ()) : State () :=
  match vals with
    | nil => state_pure tt
    | (it :: its) => perf out <- runLoopT (body it);
                    match out with
                      | Break => state_pure tt
                      | _ => foreach2' its body
                    end
  end.

Definition foreach2 (min max : nat) (body : nat -> LoopT ()) : State () :=
  foreach2' (seq min (max-min)) body.

Lemma foreach2_rule3 (min max : nat) (Inv : nat -> St -> Prop) (P : St -> Prop) (body : nat -> State ())
  : (forall (it : nat), {{fun s => Inv it s /\ P s /\ min <= it < max}} body it {{fun _ s => Inv it s /\ P s }}) -> 
    {{fun s => Inv min s /\ P s}} foreach2 min max (fun it0 => loopT_liftT (body it0)) {{fun _ s => Inv max s /\ P s}}.
    Admitted.

End monads.

Notation "m1 ;; m2" := (state_bind m1 (fun _ => m2))  (at level 60, right associativity) : monad_scope.
Notation "'perf' x '<-' m ';' e" := (state_bind m (fun x => e))
  (at level 60, x ident, m at level 200, e at level 60) : monad_scope.
Notation "{{ P }} m {{ Q }}" := (hoareTripleS P m Q)
(at level 90, format "'[' '[' {{  P  }}  ']' '/  ' '[' m ']' '['  {{  Q  }} ']' ']'") : monad_scope.
Notation "'for' i '=' max 'to' min '{{' body }}" := (foreachT max min (fun i => (loopT_liftT body))) (at level 60, i ident, min at level 60,
max at level 60, body at level 60, right associativity) : monad_scope.

Notation "'for2' i '=' min 'to' max '{{' body }}" := (foreach2 min max (fun i => (loopT_liftT body))) (at level 60, i ident, min at level 60,
max at level 60, body at level 60, right associativity) : monad_scope.

Open Scope monad_scope.
