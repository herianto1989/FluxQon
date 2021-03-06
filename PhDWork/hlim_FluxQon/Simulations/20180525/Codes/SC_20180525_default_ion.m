function ion=SC_20180525_default_ion(varargin)

P=inputParser;
P.addOptional('Site',1,@isintegerscalar);
P.addParameter('MwFrequency',2*pi*1.95e9,@isrealscalar);
P.addParameter('Decoherence','on',@(x)any(strcmpi(x,{'on','off'})));
P.addParameter('CouplingStrength',2*pi*[1e3,1e3],...
	@(x)isrealvector(x) && numel(x)==2);
P.addParameter('LineStrength',2*pi*[10,1e4,1e3],...
	@(x)isrealvector(x) && numel(x)==3);% ...
%  1st element: strength of microwave transitions.
%  2nd element: strength of optical like-to-like transitions.
%  3rd element: strength of optical unlike transitions.
P.addParameter('Radius',4e-6,@isrealscalar);
P.addParameter('Height',8e-6,@isrealscalar);
P.parse(varargin{:});
P=P.Results;

a=152;
B=runfunction({'S','C',20170621,'get','frequency'},2,1,a,270,0);
B=P.MwFrequency/B;

ion=CylinderYSOEr(...
	'Isotope',2,...
	'Multiplet',1:2,...
	'Site',P.Site,...
	'Class',1,...
	'Rotation',[a,270,0]*pi/180,...
	'MagneticField',B,...
	'Radius',P.Radius,...
	'Height',P.Height,...
	'CouplingStrength',P.CouplingStrength,...
	'LineStrength',[P.LineStrength(:);flipud(P.LineStrength(:))]);

if strcmpi(P.Decoherence,'on')
	ion.DecayRate=2*pi*[1e6,1e2,1e6];
	ion.Temperature=2e-2;
end

end
