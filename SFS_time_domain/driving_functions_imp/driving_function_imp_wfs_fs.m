function [delay,weight] = driving_function_imp_wfs_fs(x0,nx0,xs,conf)
%DRIVING_FUNCTION_IMP_WFS_FS weights and delays for a focused source in WFS
%
%   Usage: [delay,weight] = driving_function_imp_wfs_fs(x0,nx0,xs,conf)
%
%   Input parameters:
%       x0      - position  of secondary sources / m [nx3]
%       nx0     - direction of secondary sources [nx3]
%       xs      - position of focused source [nx3]
%       conf    - configuration struct (see SFS_config)
%
%   Output parameters:
%       delay   - delay of the driving function / s
%       weight  - weight (amplitude) of the driving function
%
%   See also: sound_field_imp, sound_field_imp_wfs, driving_function_mono_wfs_fs
%
%   References:
%       Start (1997) - "Direct Sound Enhancement by Wave Field Synthesis", 
%       PhD thesis, TU Delft,
%       http://resolver.tudelft.nl/uuid:c80d5b58-67d3-4d84-9e73-390cd30bde0d
%
%       Verheijen (1997) - "Sound Reproduction by Wave Field Synthesis", PhD
%       thesis, TU Delft,
%       http://resolver.tudelft.nl/uuid:9a35b281-f19d-4f08-bec7-64f6920a3821
%
%       Wierstorf (2014) - "Perceptual Assessment of Sound Field Synthesis",
%       PhD thesis, TU Berlin, https://doi.org/10.14279/depositonce-4310

%*****************************************************************************
% The MIT License (MIT)                                                      *
%                                                                            *
% Copyright (c) 2010-2018 SFS Toolbox Developers                             *
%                                                                            *
% Permission is hereby granted,  free of charge,  to any person  obtaining a *
% copy of this software and associated documentation files (the "Software"), *
% to deal in the Software without  restriction, including without limitation *
% the rights  to use, copy, modify, merge,  publish, distribute, sublicense, *
% and/or  sell copies of  the Software,  and to permit  persons to whom  the *
% Software is furnished to do so, subject to the following conditions:       *
%                                                                            *
% The above copyright notice and this permission notice shall be included in *
% all copies or substantial portions of the Software.                        *
%                                                                            *
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR *
% IMPLIED, INCLUDING BUT  NOT LIMITED TO THE  WARRANTIES OF MERCHANTABILITY, *
% FITNESS  FOR A PARTICULAR  PURPOSE AND  NONINFRINGEMENT. IN NO EVENT SHALL *
% THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER *
% LIABILITY, WHETHER  IN AN  ACTION OF CONTRACT, TORT  OR OTHERWISE, ARISING *
% FROM,  OUT OF  OR IN  CONNECTION  WITH THE  SOFTWARE OR  THE USE  OR OTHER *
% DEALINGS IN THE SOFTWARE.                                                  *
%                                                                            *
% The SFS Toolbox  allows to simulate and  investigate sound field synthesis *
% methods like wave field synthesis or higher order ambisonics.              *
%                                                                            *
% http://sfstoolbox.org                                 sfstoolbox@gmail.com *
%*****************************************************************************


%% ===== Checking of input  parameters ==================================
nargmin = 4;
nargmax = 4;
narginchk(nargmin,nargmax);
isargmatrix(x0,nx0,xs);
isargstruct(conf);


%% ===== Configuration ==================================================
% Speed of sound
c = conf.c;
xref = conf.xref;
fs = conf.fs;
dimension = conf.dimension;
driving_functions = conf.driving_functions;


%% ===== Computation =====================================================

% Get the delay and weighting factors
if strcmp('2D',dimension) || strcmp('3D',dimension)

    % === 2- or 3-Dimensional ============================================

    % For 2D the default focussed source should be a line sink
    if strcmp('2D',dimension) && strcmp('default',driving_functions)
        driving_functions = 'line_sink';
    end

    switch driving_functions
    case 'default'
        % --- SFS Toolbox ------------------------------------------------
        % d using a focused point source as source model
        %
        %                   1  (x0-xs) nx0
        % d(x0,t) = h(t) * --- ----------- delta(t+|x0-xs|/c)
        %                  2pi  |x0-xs|^2
        %
        % See http://sfstoolbox.org/#equation-d.wfs.fs
        %
        % r = |x0-xs|
        r = vector_norm(x0-xs,2);
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = 1./(2.*pi) .* vector_product(xs-x0,nx0,2) ./ r.^2;
        %
    case 'line_sink'
        % d using a focused line source as source model
        %                     ___
        %                    | 1   (x0-xs) nx0
        % d(x0,t) = h(t) * _ |--- ------------- delta(t+|x0-xs|/c)
        %                   \|2pi |x0-xs|^(3/2)
        %
        % See http://sfstoolbox.org/#equation-d.wfs.fs.ls
        %
        % r = |x0-xs|
        r = vector_norm(x0-xs,2);
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = 1./(2.*pi) .* vector_product(x0-xs,nx0,2) ./ r.^(3./2);
        %
    case 'legacy'
        % --- Old SFS Toolbox default ------------------------------------
        % d using a focused point source as source model
        %
        %                   1   (x0-xs) nx0
        % d(x0,t) = h(t) * --- ------------- delta(t+|x0-xs|/c)
        %                  2pi |x0-xs|^(3/2)
        %
        % See Wierstorf (2014) eq. (2.75)
        %
        % r = |x0-xs|
        r = vector_norm(x0-xs,2);
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = 1./(2.*pi) .* vector_product(xs-x0,nx0,2) ./ r.^(3./2);
        %
    otherwise
        error(['%s: %s, this type of driving function is not implemented', ...
            'for a focused source.'],upper(mfilename),driving_functions);
    end


elseif strcmp('2.5D',dimension)

    % === 2.5-Dimensional ================================================

    % Reference point
    xref = repmat(xref,[size(x0,1) 1]);

    switch driving_functions
    case {'default', 'reference_circle'}
        % Driving function with two stationary phase approximations,
        % reference to circle around the focused source with radius |xref-xs|
        %
        % r = |x0-xs|
        r = vector_norm(x0-xs,2);
        %
        % 2.5D correction factor
        %         _____________
        %        |        r
        % g0 = _ |1 + ---------
        %       \|    |xref-xs|
        %
        g0 = sqrt( 1 + r./vector_norm(xref-xs,2) );
        %                                  ___
        %                                 | 1    (xs-x0) nx0
        % d_2.5D(x0,t) = h_pre(-t) * g0 _ |---  ------------- delta(t+|x0-xs|/c)
        %                                \|2pi  |x0-xs|^(3/2)
        %
        % See http://sfstoolbox.org/#equation-d.wfs.fs.2.5D
        %
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = g0 ./ sqrt(2.*pi) .* vector_product(xs-x0,nx0,2) ./ r.^(3./2);
        %
    case 'reference_point'
        % Driving function with only one stationary phase approximation,
        % reference to one point in field
        %
        % r = |x0-xs|
        r = vector_norm(x0-xs,2);
        % 2.5D correction factor
        %         _____________________
        %        |      |xref-x0|
        % g0 = _ |---------------------
        %       \|||xref-x0| - |xs-x0||
        %
        % See Verheijen (1997), eq. (A.14)
        %
        g0 = sqrt( vector_norm(xref-x0,2) ./ abs(vector_norm(x0-xref,2) - r) );
        %                                  ___
        %                                 | 1    (xs-x0) nx0
        % d_2.5D(x0,t) = h_pre(-t) * g0 _ |---  ------------- delta(t+|x0-xs|/c)
        %                                \|2pi  |x0-xs|^(3/2)
        %
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = g0 ./ sqrt(2.*pi) .* vector_product(xs-x0,nx0,2) ./ r.^(3./2);
        %
    case 'reference_line'
        % Driving function with two stationary phase approximations,
        % reference to a line parallel to a LINEAR secondary source distribution
        %
        % distance ref-line to linear ssd
        dref = abs( vector_product(xref-x0,nx0,2) );
        % distance source and linear ssd
        ds = abs( vector_product(xs-x0,nx0,2) );
        %
        % 2.5D correction factor
        %        _______________________
        % g0 = \| d_ref / (d_ref - d_s)
        %
        % See Start (1997), eq. (3.16)
        %
        g0 = sqrt( dref ./ (dref - ds));
        %                                  ___
        %                                 | 1    (xs-x0) nx0
        % d_2.5D(x0,t) = h_pre(-t) * g0 _ |---  ------------- delta(t+|x0-xs|/c)
        %                                \|2pi  |x0-xs|^(3/2)
        %
        % Inverse Fourier Transform of Verheijen (1997), eq. (2.29b)
        %
        % r = |x0-xs|
        r = vector_norm(x0-xs,2);
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = g0 ./ sqrt(2.*pi) .* vector_product(xs-x0,nx0,2) ./ r.^(3./2);
        %
    case 'legacy'
        % --- SFS Toolbox ------------------------------------------------
        % 2.5D correction factor
        %        ______________
        % g0 = \| 2pi |xref-x0|
        %
        g0 = sqrt(2*pi*vector_norm(xref-x0,2));
        %
        % d_2.5D using a line sink as source model
        %
        %                        g0 (xs-x0) nx0
        % d_2.5D(x0,t) = h(t) * --- ------------- delta(t + |xs-x0|/c)
        %                       2pi |xs-x0|^(3/2)
        %
        % See Wierstorf (2014), eq. (2.76)
        %
        % r = |xs-x0|
        r = vector_norm(xs-x0,2);
        % Delay and amplitude weight
        delay = -1./c .* r;
        weight = g0 ./ (2.*pi) .* vector_product(xs-x0,nx0,2) ./ r.^(3./2);
        %
    otherwise
        error(['%s: %s, this type of driving function is not implemented', ...
          'for a 2.5D focused source.'],upper(mfilename),driving_functions);
    end
else
    error('%s: the dimension %s is unknown.',upper(mfilename),dimension);
end
