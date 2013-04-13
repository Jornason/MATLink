(* :Title: MATLink *)
(* :Context: MATLink` *)
(* :Authors:
	R. Menon (rsmenon@icloud.com)
	Sz. Horvát (szhorvat@gmail.com)
*)
(* :Package Version: 0.1 *)
(* :Mathematica Version: 9.0 *)

BeginPackage["MATLink`"]

ConnectMATLAB::usage =
	"ConnectMATLAB[] establishes a connection with the MATLink engine, but does not open an instance of MATLAB."

DisconnectMATLAB::usage =
	"DisconnectMATLAB[] closes an existing connection with the MATLink engine."

OpenMATLAB::usage =
	"OpenMATLAB[] opens an instance of MATLAB and allows you to access its workspace."

CloseMATLAB::usage =
	"CloseMATLAB[] closes a previously opened instance of MATLAB (opened via MATLink)."

ShowMATLAB::usage =
	"Show the MATLAB command window."

HideMATLAB::usage =
	"Hide the MATLAB command window."

MGet::usage =
	"MGet[var] imports the MATLAB variable named \"var\" into Mathematica.  MGet is Listable."

MSet::usage =
	"MSet[var, expr] exports the value in expr and saves it in a variable named \"var\" in MATLAB's workspace."

MEvaluate::usage =
	"MEvaluate[expr] evaluates a valid MATLAB expression (entered as a string) and displays an error otherwise."

MScript::usage =
	"MScript[filename, expr] creates a MATLAB script named \"filename\" with the contents in expr (string) and stores it on MATLAB's path, but does not evaluate it. These files will be removed when the MATLink engine is closed.\nMScript[filename] represents a callable MATLAB script that can be passed to MEvaluate."

MFunction::usage =
	"MFunction[func] creates a link to a MATLAB function for use from Mathematica.\nMFunction[filename, expr] creates a script on MATLAB's path and returns MFunction[filename].  expr (string) must be a valid MATLAB function definition."

MATLink::usage =
	"MATLink refers to the MATLink package. Set cross-session package options to this symbol."

MCell::usage = "MCell[list] forces list to be interpreted as a MATLAB cell in MSet, MFunction, etc."

MATLABCell::usage = "MATLABCell[] creates a code cell that is evaluated using MATLAB." (* TODO Make this private before release *)

Begin["`Developer`"]

(* Directories & file paths *)
$ApplicationDirectory = DirectoryName@$InputFileName;
$ApplicationDataDirectory = FileNameJoin[{$UserBaseDirectory, "ApplicationData", "MATLink"}];
$EngineSourceDirectory = FileNameJoin[{$ApplicationDirectory, "Engine", "src"}];
$BinaryDirectory = FileNameJoin[{$ApplicationDirectory, "Engine", "bin", $OperatingSystem <> IntegerString[$SystemWordLength]}];
$BinaryPath = FileNameJoin[{$BinaryDirectory, If[$OperatingSystem === "Windows", "mengine.exe", "mengine"]}];

(* Log files and related functions *)
If[!DirectoryQ@$ApplicationDataDirectory, CreateDirectory@$ApplicationDataDirectory];

$logfile = FileNameJoin[{$ApplicationDataDirectory, "MATLink.log"}]

(* Log message types:
	matlink – Standard MATLink` action
	info    – System info
	user    – User initiated action
	warning – MATLink` warning
	error   – MATLink` error
	fatal   – Fatal error; cannot recover *)
writeLog[message_, type_:"matlink"] :=
	Module[{str = OpenAppend[$logfile], date = DateString[]},
		WriteString[str, StringJoin @@ Riffle[{date, type, message, "\n"}, "\t"]];
		Close[str];
	]

clearLog[] := Module[{str = OpenWrite[$logfile]}, Close@str;]

ShowLog[] := FilePrint@$logfile

SetAttributes[message, HoldFirst]
message[m_MessageName, args___][type_] :=
	Module[{msg},
		msg = Switch[Head@m, String, m, MessageName, m /. HoldPattern[MessageName[_, s_]] :> MessageName[General, s]];
		writeLog[ToString@StringForm[msg, args], type];
		Message[m, args];
	]

(* Settings file *)
$SettingsFile = FileNameJoin[{$ApplicationDataDirectory, "init.m"}];

MATLink /: SetOptions[MATLink, opts_] :=
	With[{currOpts = Options@MATLink, str = OpenWrite@$SettingsFile},
		WriteString[str, "(* This file is automatically generated by MATLink. Do not edit this file or modify its contents.\nUse SetOptions[MATLink, {option -> value}] to modify the default options. *)\n"];
		Write[str,
			Options@MATLink = Sort@DeleteDuplicates[# ~Join~ currOpts &@ FilterRules[opts, currOpts], First@# == First@#2&]
		];
		Close@str;
		writeLog["MATLink settings changed: " <> ToString@Options@MATLink, "user"];
	]

Options@MATLink = {"DefaultMATLABDirectory" -> "/Applications/MATLAB_R2012b.app/"};
If[FileExistsQ@$SettingsFile,
	Options@MATLink = Get@$SettingsFile;,

	writeLog["Missing init.m; Creating a new file.", "matlink"];
	SetOptions[MATLink, Options@MATLink];
]

$DefaultMATLABDirectory := OptionValue[MATLink, "DefaultMATLABDirectory"];

(* Other Developer` functions *)
CompileMEngine::unsupp := "Automatically compiling the MATLink Engine from source is not supported on ``. Please compile it manually."
CompileMEngine::failed := "Automatically compiling the MATLink Engine has failed. Please try to compile it manually and ensure that the path to the MATLAB directory is set correctly in the makefile."

(* CompileMEngine[] will Abort[] on failure to avoid an infinite loop. *)
CompileMEngine[] :=
	Module[{},
		writeLog["Compiled MATLink Engine on " <> $OperatingSystem, "user"];
		CompileMEngine[$OperatingSystem]
	]

CompileMEngine["MacOSX"] :=
	Block[{dir = Directory[]},
		SetDirectory[$EngineSourceDirectory];
		PrintTemporary["Compiling the MATLink Engine from source...\n"];
		If[ Run["make -f Makefile.osx"] != 0,
			SetDirectory[dir];
			message[CompileMEngine::failed]["error"];
			Abort[];
		];
		Run["mv mengine " <> $BinaryPath];
		Run["make -f Makefile.osx clean"];
		SetDirectory[dir];
	]

CompileMEngine["Unix"] :=
	Block[{dir = Directory[], makefile},
		If[$SystemWordLength == 64, makefile="Makefile.lin64", makefile="Makefile.lin32"];
		SetDirectory[$EngineSourceDirectory];
		PrintTemporary["Compiling the MATLink Engine from source...\n"];
		If[ Run["make -f " <> makefile] != 0,
			SetDirectory[dir];
			message[CompileMEngine::failed]["error"];
			Abort[];
		];
		Run["mv mengine " <> $BinaryPath];
		Run["make -f " <> makefile <> " clean"];
		SetDirectory[dir];
	]

CompileMEngine[os_] := (message[CompileMEngine::unsupp, os]["error"]; Abort[])

CleanupTemporaryDirectories[] :=
	Module[{dirs = FileNames@FileNameJoin[{$TemporaryDirectory,"MATLink*"}]},
		writeLog[ToString@StringForm["Removed `` temporary directories", Length@dirs]];
		DeleteDirectory[#, DeleteContents -> True] & /@ dirs;
	]

randomString[n_Integer:50] :=
	StringJoin@RandomSample[Join[#, ToLowerCase@#] &@CharacterRange["A", "Z"], n]

FileHashList[] :=
	With[{dir = $ApplicationDirectory},
		{ StringTrim[#, dir], FileHash@#} & /@ Select[FileNames["*", dir <> "*", Infinity],
			Not@DirectoryQ@# && StringFreeQ[#, {".git", ".DS_Store"}] &
		]
	] // TableForm

End[] (* `Developer` *)

Begin["`Private`"]
AppendTo[$ContextPath, "MATLink`Developer`"];

(* Common error messages *)
MATLink::needs = "MATLink is already loaded. Remember to use Needs instead of Get.";
MATLink::errx = "``" (* Fill in when necessary with the error that MATLAB reports *)
MATLink::noconn = "MATLink has lost connection to the MATLAB engine; please restart MATLink to create a new connection. If this was a crash, then please try to reproduce it and open a new issue, making sure to provide all the details necessary to reproduce it."
MATLink::noerr = "No errors were found in the input expression. Check for possible invalid MATLAB assignments."
MATLink::noshow = "Showing or hiding the MATLAB command window is only supported on Windows."
General::wspo = "The MATLAB workspace is already open."
General::wspc = "The MATLAB workspace is already closed."
General::engo = "There is an existing connection to the MATLAB engine."
General::engc = "Not connected to the MATLAB engine."
General::nofn = "The `1` \"`2`\" does not exist."
General::owrt = "An `1` by that name already exists. Use \"Overwrite\" -> True to overwrite."
General::badval = "Invalid option value `1` passed to `2`. Values must match the pattern `3`"

(* Directories and helper functions/variables *)
EngineBinaryExistsQ[] := FileExistsQ[$BinaryPath];

(* Set these variables only once per session.
   This is to avoid losing connection/changing temporary directory because the user used Get instead of Needs *)
If[!TrueQ[MATLinkLoadedQ[]],
	MATLinkLoadedQ[] = True;
	MATLABInstalledQ[] = False;
	$openLink = {};
	$sessionID = "";
	$temporaryVariablePrefix = "";
	$sessionTemporaryDirectory = "";
	writeLog["Loaded MATLink`", "user"];
	writeLog["Version: " <> $Version, "info"];
	writeLog["OS: " <> $OperatingSystem, "info"];
	writeLog["MATLAB: " <> $DefaultMATLABDirectory, "info"];
	writeLog["MATLink: " <> ToString@Options@MATLink, "info"];,

	message[MATLink::needs]["warning"]
]

EngineLinkQ[LinkObject[link_String, _, _]] := ! StringFreeQ[link, "mengine.sh"];

(* To close previously opened links that were not terminated properly (possibly from a crash) *)
cleanupOldLinks[] :=
	Module[{links = Select[Links[], EngineLinkQ]},
		writeLog[ToString@StringForm["Closed `` old link objects.", Length@links]];
		LinkClose /@ links;
		MATLABInstalledQ[] = False;
	]

MScriptQ[name_String] /; MATLABInstalledQ[] :=
	FileExistsQ[FileNameJoin[{$sessionTemporaryDirectory, name <> ".m"}]]

MScriptQ[MScript[name_String, ___]] /; MATLABInstalledQ[] :=
	FileExistsQ[FileNameJoin[{$sessionTemporaryDirectory, name <> ".m"}]]

(* Check MATLAB code for syntax errors before evaluating.
   This is necessary because a bug in the engine causes it to hang if there is a syntax error. *)
errorsInMATLABCode[cmd_String] :=
	Module[
		{
			file = iMScript[randomString[], cmd],
			config = FileNameJoin[{$ApplicationDirectory, "Kernel", "MLintErrors.txt"}],
			result
		},
		eval@ToString@StringForm[
			"`1` = checkcode('`2`','-id','-config=`3`')",
			First@file, file["AbsolutePath"],config
		];
		result = List@@iMGet@First@file;
		eval@ToString@StringForm["clear `1`", First@file];
		{If[result =!= {}, "message" /. Flatten@result, None], file}
	]

cleanOutput[str_String, file_String] :=
	FixedPoint[
		StringReplace[#,
			{file -> "input",
			"[\.08" ~~ Shortest[x__] ~~ "]" :> x,
			StartOfString ~~ ">> ".. :> ">> "}
		]&,
		str
	]

validOptionsQ[func_Symbol, opts_List] :=
	With[{o = FilterRules[opts, Options[func]], patt = validOptionPatterns[func]},
		If[o =!= opts,
			message[func::optx, First@FilterRules[opts, Except[Options@func]], func]["error"]; False,
			FreeQ[If[MatchQ[#2, #1], True, message[func::badval, #2, func, #1]["error"];False] & @@@ (opts /. patt), False]
		]
	]

checkExpression[expr_] :=
	With[{invalid = Cases[MATLink`Engine`dispatcher[expr, "Throw" -> False], HoldPattern[$Failed -> x_] :> x, Infinity]},
		If[invalid === {},
			message[MATLink::noerr]["error"],
			message[MATLink::errx, "The following sub-expressions are invalid: " <> ToString@invalid <> ". Check to see if they are supported by MATLink and/or if the dimensions are consistent"]["error"];
		]
	]

SetAttributes[switchAbort, HoldRest]
switchAbort[cond_, expr_, failExpr_] :=
	Switch[cond, True, expr, False, failExpr, $Failed, Abort[]]

(* Connect/Disconnect MATLAB engine *)
SyntaxInformation[ConnectMATLAB] = {"ArgumentsPattern" -> {}}

ConnectMATLAB[] /; EngineBinaryExistsQ[] && !MATLABInstalledQ[] :=
	Module[{},
		cleanupOldLinks[];
		$openLink = Install@FileNameJoin[{$BinaryDirectory, If[$OperatingSystem === "Windows", "mengine.exe", "mengine.sh"]}];
		$sessionID = StringJoin[
			IntegerString[{Most@DateList[]}, 10, 2],
			IntegerString[List @@ Rest@$openLink],
			randomString[10]
		];
		$temporaryVariablePrefix = "MATLink" <> $sessionID;
		$sessionTemporaryDirectory = FileNameJoin[{$TemporaryDirectory, "MATLink" <> $sessionID}];
		CreateDirectory@$sessionTemporaryDirectory;
		MATLABInstalledQ[] = True;
		writeLog["Connected to the MATLink Engine"];
	]

ConnectMATLAB[] /; EngineBinaryExistsQ[] && MATLABInstalledQ[] := message[ConnectMATLAB::engo]["warning"]

ConnectMATLAB[] /; !EngineBinaryExistsQ[] :=
	Module[{},
		writeLog["Compiled MATLink Engine on " <> $OperatingSystem, "matlink"];
		CompileMEngine[$OperatingSystem];
		ConnectMATLAB[];
	]

SyntaxInformation[DisconnectMATLAB] = {"ArgumentsPattern" -> {}}

DisconnectMATLAB[] /; MATLABInstalledQ[] :=
	Module[{},
		LinkClose@$openLink;
		$openLink = {};
		DeleteDirectory[$sessionTemporaryDirectory, DeleteContents -> True];
		MATLABInstalledQ[] = False;
		writeLog["Disconnected from the MATLink Engine"];
	]

DisconnectMATLAB[] /; !MATLABInstalledQ[] := message[DisconnectMATLAB::engc]["warning"]

(* Open/Close MATLAB Workspace *)
OpenMATLAB::noopen = "Could not open a connection to MATLAB."

SyntaxInformation[OpenMATLAB] = {"ArgumentsPattern" -> {}}

OpenMATLAB[] /; MATLABInstalledQ[] :=
	Catch[
		Module[{},
			openEngine[];
			If[engineOpenQ[],
				writeLog["Opened MATLAB workspace"];
				MFunction["addpath", "Output" -> False][$sessionTemporaryDirectory];
				MFunction["cd", "Output" -> False][Directory[]],

				message[OpenMATLAB::noopen]["fatal"];Throw[$Failed, $error]
			];
		],
		$error
	] /; !engineOpenQ[];

OpenMATLAB[] /; MATLABInstalledQ[] := message[OpenMATLAB::wspo]["warning"] /; engineOpenQ[];

OpenMATLAB[] /; !MATLABInstalledQ[] :=
	Module[{},
		ConnectMATLAB[];
		OpenMATLAB[];
	]

SyntaxInformation[CloseMATLAB] = {"ArgumentsPattern" -> {}}

CloseMATLAB[] /; MATLABInstalledQ[] :=
	Module[{},
		writeLog["Closed MATLAB workspace"];
		closeEngine[]
	] /; engineOpenQ[] ;

CloseMATLAB[] /; MATLABInstalledQ[] := message[CloseMATLAB::wspc]["warning"] /; !engineOpenQ[];
CloseMATLAB[] /; !MATLABInstalledQ[] := message[CloseMATLAB::engc]["warning"];

(* Show or hide MATLAB command windows --- works on Windows only *)
SyntaxInformation[ShowMATLAB] = {"ArgumentsPattern" -> {}}
SyntaxInformation[HideMATLAB] = {"ArgumentsPattern" -> {}}

ShowMATLAB[] := (If[$OperatingSystem =!= "Windows", message[MATLink::noshow]["warning"]]; setVisible[1])
HideMATLAB[] := (If[$OperatingSystem =!= "Windows", message[MATLink::noshow]["warning"]]; setVisible[0])


(* MGet *)
MGet::unimpl = "Translating the MATLAB type \"`1`\" is not supported"

SyntaxInformation[MGet] = {"ArgumentsPattern" -> {_}};
SetAttributes[MGet,Listable]

iMGet[var_String] := convertToMathematica@get@var

MGet[var_String] /; MATLABInstalledQ[] :=
	switchAbort[engineOpenQ[],
		iMGet@var,
		message[MGet::wspc]["warning"]
	]

MGet[_String] /; !MATLABInstalledQ[] := message[MGet::engc]["warning"]

(* MSet *)
MSet::sparse = "Unsupported sparse array; sparse arrays must be one or two dimensional, and must have either only numerical or only logical (True|False) elements."
MSet::spdef = "Unsupported sparse array; the default element in numerical sparse arrays must be 0."
MSet::dupfield = "Duplicate field names not alowed in struct."

SyntaxInformation[MSet] = {"ArgumentsPattern" -> {_, _, OptionsPattern[]}};

iMSet[var_String, expr_] :=
	Internal`WithLocalSettings[
		Null,
		mset[var, convertToMATLAB[expr]],
		cleanHandles[]	(* prevent memory leaks *)
	]

Options[MSet] = {"ShowErrors" -> True}
MSet[var_String, expr_, opts : OptionsPattern[]] /; MATLABInstalledQ[] :=
	switchAbort[engineOpenQ[],
		If[(result = iMSet[var, expr]) === Null,
			result,
			Switch[OptionValue["ShowErrors"],
				True, checkExpression[expr],
				False, result
			]
		],

		message[MSet::wspc]["warning"]
	]

MSet[___] /; !MATLABInstalledQ[] := message[MSet::engc]["warning"]

(* MEvaluate *)
MEvaluate::unkw = "`1` is an unrecognized argument"

SyntaxInformation[MEvaluate] = {"ArgumentsPattern" -> {_}};

iMEvaluate[cmd_String, mlint_String : "Check"] :=
	Catch[
		Module[{result, error, file, id = randomString[], ex = $temporaryVariablePrefix <> randomString[10]},
			Switch[mlint,
				"Check", {error, file} = errorsInMATLABCode@cmd,
				"NoCheck", {error, file} = {None, {cmd}},
				_, Message[MEvaluate::unkw, mlint];Throw[$Failed,$error]
			];
			If[error === None,
				result = eval@StringJoin["
					try
						", First@file, "
					catch ", ex, "
						sprintf('%s%s%s', '", id, "', ", ex, ".getReport,'", id, "')
					end
					clear ", ex
				];
				If[MScriptQ@file, DeleteFile@file],

				If[MScriptQ@file, DeleteFile@file];
				Block[{$MessagePrePrint = Identity},
					Message[MATLink::errx, error];
					Throw[$Failed, $error]
				]
			];
			If[StringFreeQ[result,id],
				cleanOutput[result, First@file],

				First@StringCases[result, __ ~~ id ~~ x__ ~~ id ~~ ___ :>
					Block[{$MessagePrePrint = Identity},
						Message[MATLink::errx, cleanOutput[x, First@file]];
						Throw[$Failed, $error]
					]
				]
			]
		],
		$error
	]

MEvaluate[cmd_String, mlint_String : "Check"] /; MATLABInstalledQ[] :=
	switchAbort[engineOpenQ[],
		iMEvaluate[cmd, mlint],
		message[MEvaluate::wspc]["warning"]
	]

MEvaluate[MScript[name_String]] /; MATLABInstalledQ[] && MScriptQ[name] :=
	switchAbort[engineOpenQ[],
		eval[name],
		message[MEvaluate::wspc]["warning"]
	]

MEvaluate[MScript[name_String]] /; MATLABInstalledQ[] && !MScriptQ[name] :=
	message[MEvaluate::nofn,"MScript", name]["error"]

MEvaluate[___] /; !MATLABInstalledQ[] := message[MEvaluate::engc]["warning"]

(* MScript & MFunction *)
Options[MScript] = {"Overwrite" -> False};
validOptionPatterns[MScript] = {"Overwrite" -> True | False};

SyntaxInformation[MScript] = {"ArgumentsPattern" -> {_, _., OptionsPattern[]}}

iMScript[name_String, cmd_String, opts : OptionsPattern[]] :=
	Module[{file},
		file = OpenWrite[FileNameJoin[{$sessionTemporaryDirectory, name <> ".m"}], CharacterEncoding -> "UTF-8"];
		WriteString[file, cmd];
		Close[file];
		MEvaluate["rehash", "NoCheck"]; (* necessary on Windows for MATLAB to pick up new script *)
		MScript[name]
	]

MScript[name_String, cmd_String, opts : OptionsPattern[]] /; MATLABInstalledQ[] :=
	iMScript[name, cmd, opts] /; (!MScriptQ[name] || OptionValue["Overwrite"]) && validOptionsQ[MScript, {opts}]

MScript[name_String, cmd_String, opts : OptionsPattern[]] /; MATLABInstalledQ[] :=
	Module[{},
		message[MScript::owrt, "MScript"]["warning"];
		MScript@name
	]  /; MScriptQ[name] && !OptionValue["Overwrite"] && validOptionsQ[MScript, {opts}]

MScript[name_String, cmd_String, OptionsPattern[]] /; !MATLABInstalledQ[] := message[MScript::engc]["warning"]

MScript[name_String]["AbsolutePath"] /; MScriptQ[name] :=
	FileNameJoin[{$sessionTemporaryDirectory, name <> ".m"}]

MScript[name_String]["AbsolutePath"] /; !MScriptQ[name] :=
	Module[{},
		message[MScript::nofn, "MScript", name]["error"];
		Throw[$Failed, $error]
	]

MScript /: DeleteFile[MScript[name_String]] :=
	Catch[
		DeleteFile[MScript[name]["AbsolutePath"]],
		$error
	]

Options[MFunction] = {"Overwrite" -> False, "Output" -> True, "OutputArguments" -> 1};
validOptionPatterns[MFunction] = {"Overwrite" -> True | False, "Output" -> True | False, "OutputArguments" -> _Integer?Positive};
(* Since MATLAB allows arbitrary function definitions depending on the number of output arguments,
	we force the user to explicitly specify the number of outputs if it is different from the default value of 1. *)

SyntaxInformation[MFunction] = {"ArgumentsPattern" -> {_, _., OptionsPattern[]}}

MFunction::args = "The arguments at positions `1` to \"`2`\" could not be translated to MATLAB."

MFunction[name_String, opts : OptionsPattern[]][args___] /; MATLABInstalledQ[] && validOptionsQ[MFunction, {opts}] :=
	Switch[OptionValue["Output"],
		True,
		Module[{nIn = Length[{args}], nOut = OptionValue["OutputArguments"], vars, output, fails},
			vars = Table[ToString@Unique[$temporaryVariablePrefix], {nIn + nOut}];
			fails = Thread[iMSet[vars[[;;nIn]], {args}]];
			If[MemberQ[fails, $Failed],
				message[MFunction::args, Flatten@Position[fails, $Failed], name]["error"];
				output = ConstantArray[$Failed, nOut];,

				iMEvaluate[StringJoin["[", Riffle[vars[[-nOut;;]], ","], "]=", name, "(", Riffle[vars[[;;nIn]], ","], ");"], "NoCheck"];
				output = iMGet /@ vars[[-nOut;;]];
			];
			iMEvaluate[StringJoin["clear ", Riffle[vars, " "]], "NoCheck"];
			If[nOut == 1, First@output, output]
		],

		False,
		With[{vars = Table[ToString@Unique[$temporaryVariablePrefix], {Length[{args}]}]},
			fails = Thread[iMSet[vars, {args}]];
			If[MemberQ[fails, $Failed],
				message[MFunction::args, Position[fails, $Failed]]["error"],
				iMEvaluate[StringJoin[name, "(", Riffle[vars, ","], ");"], "NoCheck"];
			];
			iMEvaluate[StringJoin["clear ", Riffle[vars, " "]], "NoCheck"];
		]
	] /; engineOpenQ[]

MFunction[name_String, code_String, opts : OptionsPattern[]] /; MATLABInstalledQ[] && validOptionsQ[MFunction, {opts}] :=
	Module[{},
		If[!MScriptQ[name] || OptionValue["Overwrite"],
			MScript[name, code, "Overwrite" -> True],
			message[MFunction::owrt, "MFunction"]["warning"]
		];
		MFunction[name, Sequence @@ FilterRules[{opts}, Except["Overwrite"]]]
	]

MFunction[name_String, code_String, opts: OptionsPattern[]] /; !MATLABInstalledQ[] := message[MFunction::engc]["warning"]

MFunction /: DeleteFile[MFunction[name_String, ___]] :=
	Catch[
		DeleteFile[MScript[name]["AbsolutePath"]],
		$error
	]

MFunction[name_String, OptionsPattern[]][args___] /; MATLABInstalledQ[] := message[MFunction::wspc]["warning"] /; !engineOpenQ[]
MFunction[name_String, OptionsPattern[]][args___] /; !MATLABInstalledQ[] := message[MFunction::engc]["warning"]

End[] (* MATLink`Private` *)

(* Low level functions strongly tied with the C++ code are part of this context *)
Begin["`Engine`"]
AppendTo[$ContextPath, "MATLink`Private`"]

(* Assign to symbols defined in `Private` *)
engineOpenQ[] /; MATLABInstalledQ[] :=
	With[{msgs = Unevaluated@{LinkObject::linkd, LinkObject::linkn}},
		Catch[
			Check[
				engOpenQ[],
				message[MATLink::noconn]["fatal"];Throw[$Failed, $error],
				msgs
			] ~Quiet~ msgs,
			$error
		]
	]

engineOpenQ[] /; !MATLABInstalledQ[] := False
openEngine = engOpen;
closeEngine = engClose;
eval = engEvaluate;
get = engGet;
set = engSet;
cleanHandles = engCleanHandles;
setVisible = engSetVisible;

(* CONVERT DATA TYPES TO MATHEMATICA *)

(* The following mat* heads are inert and indicate the type of the MATLAB data returned
   by the engine. They must be part of the MATLink`Engine` context.
   Evaluation is only allowed inside the convertToMathematica function,
   which converts it to their final Mathematica form. engGet[] will always return
   either $Failed, or an expression wrapped in one of the below heads.
   Note that structs and cells may contain subexpressions of other types.
*)

convertToMathematica[expr_] :=
	With[
		{
			reshape = Switch[#2,
				{_,1}, #[[All, 1]],
				_, Transpose[#, Reverse@Range@ArrayDepth@#]
			]&,
			listToArray = First@Fold[Partition, #, Reverse[#2]]&
		},
		Block[{matCell, matStruct, matArray, matSparseArray, matLogical, matSparseLogical, matString, matCharArray, matUnknown},

			matCell[list_, {1,1}] := list[[1]];
			matCell[list_, dim_] := listToArray[list,dim] ~reshape~ dim;

			matStruct[list_, {1,1}] := list[[1]];
			matStruct[list_, dim_] := listToArray[list,dim] ~reshape~ dim;

			matSparseArray[jc_, ir_, vals_, dims_] := Transpose@SparseArray[Automatic, dims, 0, {1, {jc, List /@ ir + 1}, vals}];

			matSparseLogical[jc_, ir_, vals_, dims_] := Transpose@SparseArray[Automatic, dims, False, {1, {jc, List /@ ir + 1}, vals /. 1 -> True}];

			matLogical[list_, {1,1}] := matLogical@list[[1,1]];
			matLogical[list_, dim_] := matLogical[list ~reshape~ dim];
			matLogical[list_] := list /. {1 -> True, 0 -> False};

			matArray[list_, {1,1}] := list[[1,1]];
			matArray[list_, dim_] := list ~reshape~ dim;

			matString[str_] := str;

			matCharArray[list_, dim_] := listToArray[list,dim] ~reshape~ dim;

			matUnknown[u_] := (message[MGet::unimpl, u]["error"]; $Failed);

			expr
		]
	]

(* CONVERT DATA TYPES TO MATLAB *)

complexArrayQ[arr_] := Developer`PackedArrayQ[arr, Complex] || (Not@Developer`PackedArrayQ[arr] && Not@FreeQ[arr, Complex])

booleanQ[True | False] = True
booleanQ[_] = False

ruleQ[_Rule] = True
ruleQ[_] = False

handleQ[_handle] = True
handleQ[_] = False

structHandleQ[_String -> _handle] = True
structHandleQ[_] = False

(* the convertToMATLAB function will always end up with a handle[] if it was successful *)
mset[name_String, handle[h_Integer]] := engSet[name, h]
mset[name_, _] := $Failed

convertToMATLAB[expr_] :=
	Module[{structured,reshape = Composition[Flatten, Transpose[#, Reverse@Range@ArrayDepth@#]&]},
		structured = restructure[expr];

		Block[{MArray, MSparseArray, MLogical, MSparseLogical, MString, MCell, MStruct},
			MArray[vec_?VectorQ] := MArray[{vec}];
			MArray[arr_] :=
				With[{list = reshape@Developer`ToPackedArray@N[arr]},
					If[ complexArrayQ[list],
						engMakeComplexArray[Re[list], Im[list], Reverse@Dimensions[arr]],
						engMakeRealArray[list, Reverse@Dimensions[arr]]
					]
				];

			MString[str_String] := engMakeString[str];

			(* TODO allow casting array of 0s and 1s to logical *)
			MLogical[arr_] := engMakeLogical[Boole@reshape@arr, Reverse@Dimensions@arr];

			MCell[vec_?VectorQ] := MCell[{vec}];
			MCell[arr_?(ArrayQ[#, _, handleQ]&)] :=
				engMakeCell[reshape@arr /. handle -> Identity, Reverse@Dimensions[arr]];

			(* http://mathematica.stackexchange.com/questions/18081/how-to-interpret-the-fullform-of-a-sparsearray *)
			MSparseArray[HoldPattern@SparseArray[Automatic, {n_, m_}, def_ /; def==0, {1, {jc_, ir_}, values_}]] :=
				If[ complexArrayQ[values],
					engMakeSparseComplex[Flatten[ir]-1, jc, Re[values], Im[values], m, n],
					engMakeSparseReal[Flatten[ir]-1, jc, values, m, n]
				];
			MSparseArray[_] := (message[MSet::spdef]["error"]; $Failed);

			MSparseLogical[HoldPattern@SparseArray[Automatic, {n_, m_}, False, {1, {jc_, ir_}, values_}]] :=
				engMakeSparseLogical[Flatten[ir]-1, jc, Boole[values], m, n];

			(* If the default element of a sparse logical is not False, make it False *)
			MSparseLogical[arr_SparseArray] :=
				MSparseLogical[SparseArray[arr, Dimensions[arr], False]];

			MStruct[rules_] :=
				If[ !ArrayQ[rules, _, structHandleQ],
					$Failed,
					engMakeStruct[rules[[All,1]], rules[[All, 2, 1]], {1}]
				];

			structured (* $Failed falls through *)
		]
	]

restructure[expr_] := Catch[dispatcher[expr], $dispTag]

Options[dispatcher] = {"Throw" -> True};
dispatcher[expr_, opts : OptionsPattern[]] :=
	Switch[
		expr,

		(* packed arrays are always numeric *)
		_?Developer`PackedArrayQ,
		MArray[expr],

		(* catch sparse arrays early *)
		_SparseArray,
		handleSparse[expr],

		(* empty *)
		Null | {},
		MArray[{}],

		(* scalar *)
		_?NumericQ,
		MArray[{expr}],

		(* non-packed numerical array *)
		_?(ArrayQ[#, _, NumericQ] &),
		MArray[expr],

		(* logical scalar *)
		True | False,
		MLogical[{expr}],

		(* logical array *)
		_?(ArrayQ[#, _, booleanQ] &),
		MLogical[expr],

		(* string *)
		_String,
		MString[expr],

		(* string array *)
		(* _?(ArrayQ[#, _, StringQ] &),
		MString[expr], *)

		(* struct *)
		_?(VectorQ[#, ruleQ] &),
		MStruct[handleStruct[expr, {opts}]],

		(* cell -- may need recursion *)
		MCell[_],
		MCell[handleCell[First[expr], {opts}]],

		(* cell *)
		_List,
		MCell[handleCell[expr, {opts}]],

		(* assumed already handled, no recursion needed; only MCell and MStruct may need recursion *)
		_MArray | _MLogical | _MSparseArray | _MSparseLogical | _MString,
		expr,

		_,
		If[OptionValue["Throw"],
			Throw[$Failed, $dispTag],
			$Failed -> expr
		]
	]

handleSparse[arr_SparseArray ? (VectorQ[#, NumericQ]&) ] := MSparseArray[Transpose@SparseArray[{arr}]] (* convert to matrix *)
handleSparse[arr_SparseArray ? (MatrixQ[#, NumericQ]&) ] := MSparseArray[Transpose@SparseArray[arr]] (* the extra SparseArray call gets rid of background elements *)
handleSparse[arr_SparseArray ? (VectorQ[#, booleanQ]&) ] := MSparseLogical[Transpose@SparseArray[{arr}]]
handleSparse[arr_SparseArray ? (MatrixQ[#, booleanQ]&) ] := MSparseLogical[Transpose@SparseArray[arr]]
handleSparse[_] := (message[MSet::sparse]["error"]; Throw[$Failed, $dispTag]) (* higher dim sparse arrays or non-numerical ones are not supported *)

handleStruct[rules_ ? (VectorQ[#, ruleQ]&), throwOpt_] :=
	If[ Length@Union[rules[[All,1]]] != Length[rules],
		message[MSet::dupfield]["error"]; $Failed,
		Thread[rules[[All, 1]] -> (dispatcher[#, throwOpt]& /@ rules[[All, 2]])]
	]

handleStruct[_] := $Failed (* TODO multi-element struct *)

handleCell[list_List, throwOpt_] := dispatcher[#, throwOpt]& /@ list
handleCell[expr_, throwOpt_] := dispatcher[expr, throwOpt]

End[] (* MATLink`Engine` *)

Begin["`Experimental`"]

MATLABCell[] :=
	Module[{},
		CellPrint@Cell[
			TextData[""],
			"Program",
			Evaluatable->True,
			CellEvaluationFunction -> (MEvaluate@First@FrontEndExecute[FrontEnd`ExportPacket[Cell[#], "InputText"]] &),
			CellGroupingRules -> "InputGrouping",
			CellFrameLabels -> {{None,"MATLAB"},{None,None}}
		];
		SelectionMove[EvaluationNotebook[], All, EvaluationCell];
		NotebookDelete[];
		SelectionMove[EvaluationNotebook[], Next, CellContents]
	]

End[] (* MATLink`Experimental` *)

EndPackage[] (* MATLink` *)
