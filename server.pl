% server.pl
:- use_module(library(csv)).
:- use_module(library(http/json)).
:- use_module(library(http/http_server)).
:- use_module(library(http/http_json)).

% Load data from CSV and assert facts
data_load(FileName) :-
    csv_read_file(FileName, [_|Rows], [functor(student), arity(4)]), % Skip the first row
    maplist(assert, Rows).

% Rules for determining eligibility
eligible_for_scholarship(Student_ID) :-
    student(Student_ID, _, Attendance_Percentage, CGPA),
    Attendance_Percentage >= 75,
    CGPA >= 9.0.

permitted_for_exam(Student_ID) :-
    student(Student_ID, _, Attendance_Percentage, CGPA),
    (Attendance_Percentage >= 75; 
    CGPA >= 9.0).

%%
% Include the HTTP headers for CORS
cors_headers :-
    format('Access-Control-Allow-Origin: *~n'),
    format('Access-Control-Allow-Methods: GET, POST, OPTIONS~n'),
    format('Access-Control-Allow-Headers: Content-Type~n').

% Handle CORS preflight requests
handle_options(Request) :-
    memberchk(method(options), Request),
    cors_headers,
    format('Content-type: text/plain~n~n'),
    format('OK~n').

% Endpoint to check scholarship eligibility
check_scholarship(Request) :-
    (   memberchk(method(options), Request) % Handle CORS preflight for this endpoint
    ->  handle_options(Request)
    ;   http_parameters(Request, [id(Student_ID, [atom])]),
        cors_headers,
        (   student(Student_ID, _, _, _) % Check if the student exists
        ->  (   eligible_for_scholarship(Student_ID)
            ->  Response = json([status="eligible", message="Student qualifies for scholarship"])
            ;   Response = json([status="ineligible", message="Student does not qualify for scholarship"])
            )
        ;   Response = json([status="not_found", message="Student with this ID does not exist"])
        ),
        reply_json(Response)
    ).

% Endpoint to check exam permission
check_exam(Request) :-
    (   memberchk(method(options), Request) % Handle CORS preflight for this endpoint
    ->  handle_options(Request)
    ;   http_parameters(Request, [id(Student_ID, [atom])]),
        cors_headers,
        (   student(Student_ID, _, _, _) % Check if the student exists
        ->  (   permitted_for_exam(Student_ID)
            ->  Response = json([status="permitted", message="Student is permitted for the exam"])
            ;   Response = json([status="debarred", message="Student is not permitted for the exam"])
            )
        ;   Response = json([status="not_found", message="Student with this ID does not exist"])
        ),
        reply_json(Response)
    ).
%%

% Start server on localhost:8080
:- http_server(http_dispatch, [port(8080)]).

% Define API endpoints
:- http_handler('/eligibility/scholarship', check_scholarship, []).
:- http_handler('/eligibility/exam', check_exam, []).

