# Copyright 2021-2025 The MathWorks, Inc.

from abc import ABC, abstractmethod
from typing import NamedTuple, Set


class CloudCapacity(NamedTuple):
    """Class defining the cloud-computing platform capacity information."""

    desired_nodes: int
    minimum_nodes: int
    maximum_nodes: int
    current_nodes: int
    workers_per_node: int


class AbstractCloudInterface(ABC):
    """Class to interact with a cloud-computing platform."""

    @abstractmethod
    def get_cloud_capacity(self) -> CloudCapacity:
        """Get the cloud-computing platform capacity info
        as well as the number of workers per node.

        Returns:
            info (CloudCapacity): Cloud-computing limits.
        """
        pass

    @abstractmethod
    def get_idle_timeout_seconds(self) -> int:
        """Get the idle timeout specified on the cloud-computing platform.
        This timeout specifies the minimum idle time to consider a worker to be
        idle.

        Returns:
            timeout (int): Idle timeout in seconds.
        """
        pass

    @abstractmethod
    def get_worker_nodes(self) -> Set[str]:
        """Get the current worker nodes running on the cloud-computing
        platform. Only the nodes in a good state (online and healthy) will be
        returned.

        Returns:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
        """
        pass

    @abstractmethod
    def set_cloud_capacity(self, desired_nodes: int) -> bool:
        """Update the cloud-computing platform desired capacity.

        Args:
            desired_nodes (int): Desired number of worker nodes.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        pass

    @abstractmethod
    def set_min_nodes(self, nodes: int) -> bool:
        """Update the cloud-computing platform minimum capacity.

        Args:
            nodes (int): Minimum number of worker nodes.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        pass

    @abstractmethod
    def set_nodes_unhealthy(self, nodes_hostnames: Set[str]) -> bool:
        """Indicate to the cloud-computing platform that multiple nodes are no
        longer healthy. The cloud-computing platform will terminate the nodes
        shortly.

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes to mark.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        pass

    @abstractmethod
    def get_cluster_termination_policy(self) -> str:
        """Get the termination policy for the cluster. This policy is
        specified as a tag on the head node.
        Returns:
            policy (str): Termination policy.
        """
        pass

    @abstractmethod
    def set_cluster_termination_policy(self, policy: str) -> bool:
        """Set the termination policy for the cluster. This policy is
        specified as a tag on the head node.
        Args:
            policy (str): Termination policy.
        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        pass
    
    @abstractmethod
    def set_mwstate_tag(self, state: str) -> bool:
        """
        Set the mwstate tag on the cluster head node.

        Args:
            state (str): The state to set on the mwstate tag.
            Accepted values are 'ready' or 'timeout'.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        pass

    @abstractmethod
    def set_nodes_protection(
        self, nodes_hostnames: Set[str], protect: bool
    ) -> Set[str]:
        """Update multiple nodes' protection status. When a node is
        protected, the cloud-computing platform cannot terminate it
        automatically.

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
            protect (bool): Protection state to set.

        Returns:
            nodes_success (Set[str]): Hostnames of the nodes for which the
            operation was successful.
        """
        pass

    @abstractmethod
    def unprotect_all_nodes(self) -> bool:
        """
        Sets instance protection as false for all active instances
        in the auto-scaling group.
        Returns:
            True: When the operation succeeds.
            False: If setting instance protection fails for an instance.
        """
        pass

    @staticmethod
    @abstractmethod
    def is_spot_instance_marked_for_removal() -> bool:
        """Checks whether the Spot instance is identified to be
        removed by the cloud provider.
        Returns:
            True: When the Spot instance is identified by the cloud
            provider to be removed.
            False: When the Spot instance is not marked for removal
            by the cloud provider.
        """
        pass
