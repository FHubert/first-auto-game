class_name SolverCancel
extends RefCounted
## Token anulowania dla SortSolver.solve (T-222). Ustawiany z watku glownego, czytany
## w watku roboczym; zapis/odczyt bool jest atomowy, wiec Mutex nie jest potrzebny
## (najwyzej solver zauwazy flage o jedno sprawdzenie pozniej).

var cancelled: bool = false
