function X = vgg_X_from_xP_lin(u,P,imsize)
% VGG_X_FROM_XP_LIN - Linear triangulation of 3D point from image points
%
% Usage: X = vgg_X_from_xP_lin(u,P,imsize)
%
% Inputs:
%   u - 2xK matrix of image points (u,v) for K cameras
%   P - 3x4xK matrix of projection matrices for K cameras
%   imsize - 2xK matrix of image sizes (width,height) for K cameras
%
% Outputs:
%   X - 4x1 triangulated 3D point in homogenous coordinates

% If P is a cell array, concatenate it into a single 3D matrix
if iscell(P)
  P = cat(3,P{:});
end

% Get the number of cameras (K)
K = size(P,3);

% Precondition the projection matrices and image points
if nargin>2
  for k = 1:K
    % Construct the normalization matrix H for the k-th image
    H = [2/imsize(1,k) 0 -1
         0 2/imsize(2,k) -1
         0 0              1];
    % Normalize the projection matrix and image points
    P(:,:,k) = H*P(:,:,k);
    u(:,k) = H(1:2,1:2)*u(:,k) + H(1:2,3);
  end
end

% Compute the augmented matrix A for each camera
A = [];
for k = 1:K
  % Compute the augmented matrix A for the k-th camera
  A = [A; vgg_contreps([u(:,k);1])*P(:,:,k)];
end
% A = normx(A')'; % This line seems to be commented out, but the commented version is included for reference

% Perform SVD on the augmented matrix A to get the 3D point X
[~,~,X] = svd(A,0);
X = X(:,end);

% Adjust the orientation of the 3D point X to be consistent with the projection matrices
s = reshape(P(3,:,:),[4 K])'*X;
if any(s<0)
  % If the orientation is incorrect, negate X
  X = -X;
  % Check if the new orientation is also incorrect
  if any(s>0)
    % If the new orientation is also incorrect, issue a warning
    % warning('Inconsistent orientation of point match');
  end
end

return

