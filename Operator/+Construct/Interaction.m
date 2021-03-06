function [H,d]=Interaction(varargin)
%% Construct Interaction Hamiltonian
%  H=Construct.Interaction(obj1,obj2,obj3,...,objN) returns the Hamiltonian for
%    all the interactions between any two objects in {obj1,obj2,obj3,...}. The
%    dimension of the Hamiltonian is equal to the product of the Hilbert
%    dimension of each object.
%
%  H=Construct.Interaction(d,n1,obj1,n2,obj2,...,nN,objN) returns the
%    interaction Hamiltonian with the kronecker product dimensions specified in
%    d. The Hilbert subspace for obj_i is positioned at index n_i.
%
%  H=Construct.Interaction(obj1,obj2,obj3,...,objN,CIX)
%  H=Construct.Interaction(d,n1,obj1,n2,obj2,...,nN,objN,CIX)
%    returns only the Hamiltonian for the interactions between any two objects
%    in the combination pairs specified in the matrix CIX. CIX is a matrix of
%    size M x 2 where the elements are integers {1,2,3,...,N} that correspond to
%    the indices of the objects in the list. Each row in CIX specifies a
%    combination between two indices (Xi,Xj), which is used to mark that the
%    interaction between obj_i and obj_j should be added into the Hamiltonian.
%
%  H=Construct.Interaction(...,'RWA') constructs the interaction Hamiltonian
%    with the Rotating Wave Approximation.
%
% Optional outputs:
%  - d : List of the Hilbert-subspace dimensions, returned as an integer vector.
%        The product of the elements in d is equal to the dimension of H.
%
% Requires package:
%  - MatCommon_v1.0.0+
%  - PhysConst_v1.0.0+
%
% Tested on:
%  - MATLAB R2017a
%
% See also: Hamiltonian, Lindblad.
%
% Copyright: Herianto Lim (http://heriantolim.com)
% Licensing: GNU General Public License v3.0
% First created: 09/06/2017
% Last modified: 01/08/2017

%% Constants
DEFINED_CLASS={'Qubit','Ion','Photon'};
DISPERSION_IGNORE=1000;

%% Input Parsing and Validation
H=0;
d=1;
K=nargin;
if K<2
	return
end

if isstringscalar(varargin{K})
	if strcmpi(varargin{K},'RWA')
		rwa=true;
		K=K-1;
	else
		error('FluxQon:Construct:Interaction:InvalidInput',...
			'Invalid option specifier.');
	end
else
	rwa=false;
end

if isintegermatrix(varargin{K})
	if isempty(varargin{K})
		return
	elseif size(varargin{K},2)==2
		CIX=varargin{K};
		K=K-1;
	else
		error('FluxQon:Construct:Interaction:InvalidInput',...
			'Input to the interaction markup matrix must have two columns.');
	end
else
	CIX=[];
end

if isintegervector(varargin{1})
	J=(K-1)/2;
	assert(floor(J)>=J,...
		'FluxQon:Construct:Interaction:WrongNargin',...
		'Incorrect number of input arguments.');
	assert(all(varargin{1}>0),...
		'FluxQon:Construct:Interaction:InvalidInput',...
		'Input to the subspace dimensions must be a positive integer vector.');
	d=varargin{1};
	k=2*(1:J);
	assert(all(cellfun(@(x)isintegerscalar(x) && x>0,varargin(k))),...
		'FluxQon:Construct:Interaction:InvalidInput',...
		'Input to the subspace indices must be a positive integer scalar.');
	n=[varargin{k}];
	varargin=varargin(k+1);
else
	J=K;
	d=[];
	n=1:J;
	varargin=varargin(n);
end

assert(all(cellfun(@isobject,varargin)),...
	'FluxQon:Construct:Interaction:InvalidInput',...
	'The input objects must belong to a user-defined class.');

if isempty(d)
	d=Hilbert.dimension(varargin{:});
end

if isempty(CIX)
	CIX=nchoosek(1:J,2);
elseif any(any(CIX>J | CIX<1))
	error('FluxQon:Construct:Interaction:InvalidInput',...
		['The elements in the interaction markup matrix must be an integer ',...
			'between 1 and the number of objects.']);
elseif any(CIX(:,1)==CIX(:,2))
	error('FluxQon:Construct:Interaction:InvalidCase',...
		'Self-interaction is not allowed.');
end

c=cell(1,J);
K=numel(DEFINED_CLASS);
f1=false;
for j=1:J
	k=1;
	while k<=K
		if isa(varargin{j},DEFINED_CLASS{k})
			c{j}=DEFINED_CLASS{k};
			break
		end
		k=k+1;
	end
	if k>K
		f1=true;
	end
end
if f1
	warning('FluxQon:Construct:Interaction:UnrecognizedInput',...
		'Some of the input objects do not belong to the defined classes.');
end

%% Interaction Hamiltonian
j=1;
J=size(CIX,1);
f1=false;
while j<=J
	c1=c{CIX(j,1)};
	c2=c{CIX(j,2)};
	if isempty(c1) || isempty(c2)
		j=j+1;
		continue
	end
	n1=n(CIX(j,1));
	n2=n(CIX(j,2));
	obj1=varargin{CIX(j,1)};
	obj2=varargin{CIX(j,2)};
	f2=true;
	switch c1
		case 'Ion'
			M=numel(obj1.Multiplet);
			MD=(2*obj1.ElectronSpin+1)*(2*obj1.NuclearSpin+1);
			LD=M*MD;
			switch c2
				case 'Qubit'
					g=Constant.ReducedPlanck*obj1.CouplingStrength;
					assert(numel(g)==M*MD*(MD-1)/2,...
						'FluxQon:Construct:Interaction:InvalidParam',...
						'Incorrect number of elements in the coupling strength.');
					if rwa
						i=0;
						for Mi=1:M
							for Ji=1:MD
								for Jj=(Ji+1):MD
									i=i+1;
									H=H+g(i)*Operator.kron(d,...
											n1,obj1.Transition(Ji,Mi,Jj,Mi),...
											n2,obj2.Creation) ...
										+g(i)*Operator.kron(d,...
											n1,obj1.Transition(Jj,Mi,Ji,Mi),...
											n2,obj2.Annihilation);
								end
							end
						end
					else
						E1=obj1.Energy;
						if isa(obj1,'Cylinder') && isa(obj2,'Circle')
							k=integral2(@(r,z)(Circle.GCFr(obj2.Radius,r,z)).^2.*r,...
								0,obj1.Radius,0,obj1.Height);
							k=sqrt(k/obj1.Height)/obj1.Radius;
							k=k*Constant.VacuumPermeability*obj2.TunnelingEnergy ...
								/4/Constant.FluxQuantum;
							k=k*(E1-E1(1)-kron(obj1.MultipletEnergy,[1;1]));
						else
							error('FluxQon:Construct:Interaction:UnexpectedCase',...
								['The XZ coupling strength between the qubit and ',...
									'the ions could not be determined.']);
						end
						for Li=2:LD
							H=H+k(Li)*Operator.kron(d,...
								n1,obj1.Number(Li),...
								n2,obj2.Creation+obj2.Annihilation);
						end
						i=0;
						for Mi=1:M
							for Ji=1:MD
								for Jj=(Ji+1):MD
									i=i+1;
									H=H+g(i)*Operator.kron(d,...
											n1,obj1.Transition(Ji,Mi,Jj,Mi) ...
												+obj1.Transition(Jj,Mi,Ji,Mi),...
											n2,obj2.Creation+obj2.Annihilation);
								end
							end
						end
					end
				case 'Photon'
					g=Constant.ReducedPlanck*obj1.LineStrength;
					K=size(g,1);
					if K==1
						g=g*ones(LD);
					elseif K~=LD
						error('FluxQon:Construct:Interaction:InvalidCase',...
							['The matrix dimension of the ion''s line strength is ',...
								'expected to be equal to the number of the ion''s ',...
								'energy levels.']);
					end
					E1=obj1.Energy;
					E2=obj2.Energy;
					if rwa
						for Li=1:LD
							for Lj=(Li+1):LD
								K=abs(E1(Li)-E1(Lj));
								if abs(K-E2)/min(K,E2)<=DISPERSION_IGNORE
									H=H+g(Li,Lj)*Operator.kron(d,...
											n1,obj1.Transition(Li,Lj),n2,obj2.Creation) ...
										+g(Lj,Li)*Operator.kron(d,...
											n1,obj1.Transition(Lj,Li),n2,obj2.Annihilation);
								end
							end
						end
					else
						g=abs(g);
						for Li=1:LD
							for Lj=(Li+1):LD
								K=abs(E1(Li)-E1(Lj));
								if abs(K-E2)/min(K,E2)<=DISPERSION_IGNORE
									H=H+g(Li,Lj)*Operator.kron(d,...
										n1,obj1.Transition(Li,Lj)+obj1.Transition(Lj,Li),...
										n2,obj2.Annihilation+obj2.Creation);
								end
							end
						end
					end
				otherwise
					f2=false;
			end
		case 'Qubit'
			switch c2
				case 'Photon'
					E1=obj1.Energy;
					E2=obj2.Energy;
					if abs(E1-E2)/min(E1,E2)<=DISPERSION_IGNORE
						if isa(obj1,'FluxQubit')
							g=pi*obj1.Area*obj1.TunnelingEnergy ...
								/Constant.FluxQuantum*obj2.MagneticAmplitude;
						else
							error('FluxQon:Construct:Interaction:UnexpectedCase',...
								['The coupling strength between the qubit and ',...
									'the photon could not be determined.']);
						end
						if rwa
							g=abs(g);
							H=H+g*Operator.kron(d,...
									n1,obj1.Annihilation,n2,obj2.Creation) ...
								+g*Operator.kron(d,...
									n1,obj1.Creation,n2,obj2.Annihilation);
						else
							H=H+abs(g)*Operator.kron(d,...
								n1,obj1.Annihilation+obj1.Creation,...
								n2,obj2.Annihilation+obj2.Creation);
						end
					end
				otherwise
					f2=false;
			end
		otherwise
			f2=false;
	end
	if f1 || f2% continue
		f1=false;
		j=j+1;
	else% swap the paired indices
		f1=true;
		CIX(j,[1,2])=CIX(j,[2,1]);
	end
end

end
