/* mengine.tm
 *
 * Copyright 2013 Sz. Horvát and R. Menon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


:Evaluate:		Begin["MATLink`Engine`"]

:Begin:
:Function:		eng_open
:Pattern:		engOpen[]
:Arguments:		{}
:ArgumentTypes:	{}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_open_q
:Pattern:		engOpenQ[]
:Arguments:		{}
:ArgumentTypes:	{}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_close
:Pattern:		engClose[]
:Arguments:		{}
:ArgumentTypes:	{}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_evaluate
:Pattern:		engEvaluate[command_]
:Arguments:		{command}
:ArgumentTypes:	{UTF8String}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_getbuffer
:Pattern:		engGetBuffer[]
:Arguments:		{}
:ArgumentTypes:	{}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_get
:Pattern:		engGet[name_String]
:Arguments:		{name}
:ArgumentTypes:	{String}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_RealArray
:Pattern:		engMakeRealArray[list_, dims_]
:Arguments:		{list, dims}
:ArgumentTypes:	{Real64List, Integer32List}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_ComplexArray
:Pattern:		engMakeComplexArray[real_, imag_, dims_]
:Arguments:		{real, imag, dims}
:ArgumentTypes:	{Real64List, Real64List, Integer32List}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_Logical
:Pattern:		engMakeLogical[list_, dims_]
:Arguments:		{list, dims}
:ArgumentTypes:	{Integer16List, Integer32List}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_SparseReal
:Pattern:		engMakeSparseReal[ir_, jc_, real_, m_, n_]
:Arguments:		{ir, jc, real, m, n}
:ArgumentTypes:	{Integer32List, Integer32List, Real64List, Integer32, Integer32}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_SparseComplex
:Pattern:		engMakeSparseComplex[ir_, jc_, real_, imag_, m_, n_]
:Arguments:		{ir, jc, real, imag, m, n}
:ArgumentTypes:	{Integer32List, Integer32List, Real64List, Real64List, Integer32, Integer32}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_SparseLogical
:Pattern:		engMakeSparseLogical[ir_, jc_, logicals_, m_, n_]
:Arguments:		{ir, jc, logicals, m, n}
:ArgumentTypes:	{Integer32List, Integer32List, Integer16List, Integer32, Integer32}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_String
:Pattern:		engMakeString[string_]
:Arguments:		{string}
:ArgumentTypes:	{UTF16String}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_make_Struct
:Pattern:		engMakeStruct[fields_, handles_, dims_]
:Arguments:		{fields, handles, dims}
:ArgumentTypes:	{Manual}
:ReturnType:	Manual
:End:



:Begin:
:Function:		eng_make_Cell
:Pattern:		engMakeCell[handles_, dims_]
:Arguments:		{handles, dims}
:ArgumentTypes:	{Integer32List, Integer32List}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_clean_handles
:Pattern:		engCleanHandles[]
:Arguments:		{}
:ArgumentTypes:	{}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_get_handles
:Pattern:		engGetHandles[]
:Arguments:		{}
:ArgumentTypes:	{}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_set
:Pattern:		engSet[name_, handle_]
:Arguments:		{name, handle}
:ArgumentTypes:	{String, Integer32}
:ReturnType:	Manual
:End:


:Begin:
:Function:		eng_set_visible
:Pattern:		engSetVisible[value_]
:Arguments:		{value}
:ArgumentTypes:	{Integer32}
:ReturnType:	Manual
:End:


:Evaluate:		End[]
