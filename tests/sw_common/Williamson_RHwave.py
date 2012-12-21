from math import pi, cos, sin
from numpy import dot
from fluidity.spheretools import cart2polar, spherical_basis_vecs

a=6.37122e6
K=7.848e-6
R=4
omega=7.292e-5
w=K
h0=8e3
g=9.80616

def initial_velocity():

    def sol(X,t):
        ([theta,phi])=cart2polar(X)
        u=a*w*cos(phi)+a*K*cos(phi)**(R-1)*(R*sin(phi)**2-cos(phi)**2)*cos(R*theta)
        v=-a*K*R*cos(phi)**(R-1)*sin(phi)*sin(R*theta)
        M=spherical_basis_vecs(X)
        return (dot(M,[u,v]))

    return sol

def initial_height():

    def sol(X,t):
        ([theta,phi])=cart2polar(X)

        A=0.5*w*(2*omega+w)*cos(phi)**2+0.25*K**2*cos(phi)**(2*R)*((R+1)*cos(phi)**2+(2*R**2-R-2)-2*R**2*cos(phi)**-2)
        B=((2*(omega+w)*K)/((R+1)*(R+2)))*cos(phi)**R*((R**2+2*R+2)-(R+1)**2*cos(phi)**2)
        C=0.25*K**2*cos(phi)**(2*R)*((R+1)*cos(phi)**2-(R+2))

        return h0+(a**2/g)*(A+B*cos(R*theta)+C*cos(2*R*theta))

    return sol

def initial_streamfn():

    def sol(X,t):
        ([theta,phi])=cart2polar(X)

        return a**2*(-w*sin(phi)+K*(cos(phi)**R)*sin(phi)*cos(R*theta))

    return sol
