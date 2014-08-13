classdef Container < drakeFunction.Root
  % Abstract parent class for functions that pass their 
  properties (SetAccess = immutable)
    contained_functions %Cell array of DrakeFunction objects
    n_contained_functions
    same_input
    same_output
    input_map
  end

  methods (Static, Abstract)
    [f,df] = combineOutputs(obj,f_cell,df_cell)
  end

  methods
    function obj = Container(fcns,same_input,same_output)
      if nargin < 2, same_input = false; end
      if nargin < 3, same_output = false; end
      typecheck(fcns,'cell');
      assert(all(cellfun(@(arg)isa(arg,'drakeFunction.Root'), fcns)));

      [input_frame,input_map] = drakeFunction.Container.constructInputFrame(fcns,same_input);
      output_frame = drakeFunction.Container.constructOutputFrame(fcns,same_output);

      obj = obj@drakeFunction.Root(input_frame, output_frame);

      obj.contained_functions = fcns;
      obj.n_contained_functions = numel(fcns);
      obj.same_input = same_input;
      obj.same_output = same_output;
      obj.input_map = input_map;
    end

    function [f,df] = eval(obj,x)
      [f_cell,df_cell] = evalContainedFunctions(obj,x);
      [f,df] = combineOutputs(obj,f_cell,df_cell);
    end

    function [f_cell,df_cell] = evalContainedFunctions(obj,x)
      x_cell = cell(1,obj.n_contained_functions);
      f_cell = cell(size(x_cell));
      df_cell = cell(size(x_cell));
      if obj.same_input
        x_cell(:) = {x};
      else
        x_cell = splitCoordinates(obj.input_frame, x);
      end
      contained_functions_local = obj.contained_functions;
      for i = 1:obj.n_contained_functions
        [f_cell{i},df_cell{i}] = contained_functions_local{i}.eval(reshape([x_cell{obj.input_map{i}}],[],1));
      end
    end

  end

  methods (Static)
    function [input_frame, input_frame_to_fcn_map] = constructInputFrame(fcns, same_input)
      if nargin < 2, same_input = false; end
      fcn_input_frames = cellfun(@(fcn) fcn.getInputFrame(), ...
        fcns,'UniformOutput',false);
      if same_input
        % Check that all elements of fcns have the same input_frame
        input_frame = fcn_input_frames{1};
        assert(all(cellfun(@(frame) frame==input_frame,fcn_input_frames)), ...
          'Drake:DrakeFunction:InputFramesDoNotMatch', ...
          ['If ''same_input'' is set to true, all functions must ' ...
           'have the same input frame']);
        input_frame_to_fcn_map = repmat({1:input_frame.getNumFrames()},numel(fcns),1);
      else
        input_frame_to_fcn_map = cell(1,numel(fcns));
        input_frame_to_fcn_map{1} = 1:fcn_input_frames{1}.getNumFrames();
        for i = 2:numel(fcns)
          input_frame_to_fcn_map{i} = input_frame_to_fcn_map{i-1}(end)+(1:fcn_input_frames{i}.getNumFrames()); 
        end
        input_frame = MultiCoordinateFrame(fcn_input_frames);
      end
    end

    function output_frame = constructOutputFrame(fcns, same_output)
      if nargin < 2, same_output = false; end
      fcn_output_frames = cellfun(@(fcn) fcn.getOutputFrame(), ...
        fcns,'UniformOutput',false);
      if same_output
        % Check that all elements of fcns have the same output_frame
        output_frame = fcn_output_frames{1};
        assert(all(cellfun(@(frame) frame==output_frame,fcn_output_frames)), ...
          'Drake:DrakeFunction:OutputFramesDoNotMatch', ...
          ['If ''same_output'' is set to true, all functions must ' ...
           'have the same output frame']);
      else
        output_frame = MultiCoordinateFrame(fcn_output_frames);
      end
    end

  end
end
